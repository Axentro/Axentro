include Sushi::Core
include Hashes

describe Wallet do

  describe "create new wallet" do

    it "should create a new wallet on the testnet" do
      wallet = Wallet.from_json(Wallet.create(true).to_json)
      Wallet.verify!(wallet.secret_key,wallet.public_key_x, wallet.public_key_y, wallet.address).should be_true
      Wallet.address_network_type(wallet.address).should eq({prefix: "T0", name: "testnet"})
    end

    it "should create a new wallet on the mainnet" do
      wallet = Wallet.from_json(Wallet.create(false).to_json)
      Wallet.verify!(wallet.secret_key,wallet.public_key_x, wallet.public_key_y, wallet.address).should be_true
      Wallet.address_network_type(wallet.address).should eq({prefix: "M0", name: "mainnet"})
    end
  end

  describe "verify wallet" do

    it "should verify a valid wallet" do
      wallet = Wallet.from_json(Wallet.create(true).to_json)
      Wallet.verify!(wallet.secret_key,wallet.public_key_x, wallet.public_key_y, wallet.address).should be_true
    end

    it "should raise an invalid checksum error when address is invalid" do
       expect_raises(Exception, "Invalid checksum for invalid-wallet-address") do
         wallet = Wallet.from_json(Wallet.create(true).to_json)
         Wallet.verify!(wallet.secret_key,wallet.public_key_x, wallet.public_key_y, "invalid-wallet-address")
       end
    end

    it "should raise an invalid public key error when public_key_raw_x does not match public_key_x" do
       wallet1 = Wallet.from_json(Wallet.create(true).to_json)
       wallet2 = Wallet.from_json(Wallet.create(true).to_json)

       expected_keys = create_expected_keys(wallet1.public_key_x, wallet1.public_key_y, wallet2.secret_key)
       public_key_raw_x = expected_keys[:public_key_raw_x]
       public_key_x = expected_keys[:public_key_x]

       expect_raises(Exception, "Invalid public key (public_key_x) for #{public_key_raw_x} != #{public_key_x}") do
         Wallet.verify!(wallet2.secret_key,wallet1.public_key_x, wallet1.public_key_y, wallet1.address).should be_true
       end
    end

    it "should raise an invalid public key error when public_key_raw_y does not match public_key_y" do
       wallet1 = Wallet.from_json(Wallet.create(true).to_json)
       wallet2 = Wallet.from_json(Wallet.create(true).to_json)

       expected_keys = create_expected_keys(wallet1.public_key_x, wallet2.public_key_y, wallet1.secret_key)
       public_key_raw_y = expected_keys[:public_key_raw_y]
       public_key_y = expected_keys[:public_key_y]

       expect_raises(Exception, "Invalid public key (public_key_y) for #{public_key_raw_y} != #{public_key_y}") do
         Wallet.verify!(wallet1.secret_key,wallet1.public_key_x, wallet2.public_key_y, wallet1.address)
       end
    end

    it "should verify a valid wallet using the instance method verify!" do
      wallet1 = Wallet.from_json(Wallet.create(true).to_json)
      wallet2 = Wallet.new(wallet1.secret_key, wallet1.public_key_x, wallet1.public_key_y, wallet1.address)
      wallet2.verify!.should be_true
    end

  end

  describe "#valid_checksum?" do

    it "should return true when valid checksum" do
      wallet = Wallet.from_json(Wallet.create(true).to_json)
      Wallet.valid_checksum?(wallet.address).should be_true
    end

    it "should return false when invalid checksum" do
      Wallet.valid_checksum?("invalid-wallet-address").should be_false
    end

  end

  describe "#address_network_type?" do

    it "should return testnet with a valid testnet address" do
      wallet = Wallet.from_json(Wallet.create(true).to_json)
      Wallet.address_network_type(wallet.address).should eq({prefix: "T0", name: "testnet"})
    end

    it "should return mainnet with a valid mainnet address" do
      wallet = Wallet.from_json(Wallet.create(false).to_json)
      Wallet.address_network_type(wallet.address).should eq({prefix: "M0", name: "mainnet"})
    end

    it "should raise an invalid checksum error when address is invalid" do
      expect_raises(Exception, "Invalid checksum for the address: invalid-wallet-address") do
        Wallet.address_network_type("invalid-wallet-address")
      end
    end

    it "should raise an invalid network error when address not mainnet or testnet" do
      expect_raises(Exception, "Invalid network: U0") do
        Wallet.address_network_type(create_unknown_network_address)
      end
    end
  end

  describe "#public_key_to_address" do

    it "should create an address from a public key for the testnet" do
      public_key = Wallet.create_key_pair[:public_key]
      address = Wallet.public_key_to_address(public_key, true)
      Wallet.address_network_type(address).should eq({prefix: "T0", name: "testnet"})
    end

    it "should create an address from a public key for the mainnet" do
      public_key = Wallet.create_key_pair[:public_key]
      address = Wallet.public_key_to_address(public_key, false)
      Wallet.address_network_type(address).should eq({prefix: "M0", name: "mainnet"})
    end
  end

  it "should create a key pair" do
    key_pair = Wallet.create_key_pair
    address = Wallet.public_key_to_address(key_pair[:public_key], true)

    secret_key = Base64.strict_encode(key_pair[:secret_key].to_s(base: 10))
    public_key_x = Base64.strict_encode(key_pair[:public_key].x.to_s(base: 10))
    public_key_y = Base64.strict_encode(key_pair[:public_key].y.to_s(base: 10))

    Wallet.verify!(secret_key, public_key_x, public_key_y, address).should be_true
  end

  describe "#from_path" do

    it "should find a wallet from the supplied path" do
      test_wallet_0 = "#{__DIR__}/../../../wallets/testnet-0.json"
      wallet = Wallet.from_path(test_wallet_0)
      Wallet.verify!(wallet.secret_key, wallet.public_key_x, wallet.public_key_y, wallet.address).should be_true
    end

   it "should raise a wallet not found error when no wallet file exists at the specific path" do
     expect_raises(Exception, "Failed to find wallet at invalid-path, create it first!") do
       Wallet.from_path("invalid-path")
     end
   end
  end
end

def create_expected_keys(key_x, key_y, secret_key)
  secp256k1 = ECDSA::Secp256k1.new
  public_key_raw_x = BigInt.new(Base64.decode_string(key_x), base: 10)
  public_key_raw_y = BigInt.new(Base64.decode_string(key_y), base: 10)

  secret_key_raw = BigInt.new(Base64.decode_string(secret_key), base: 10)
  public_key = secp256k1.create_key_pair(secret_key_raw)[:public_key]
  public_key_x = public_key.x.to_s(base: 10)
  public_key_y = public_key.y.to_s(base: 10)
  {public_key_raw_x: public_key_raw_x, public_key_x: public_key_x, public_key_raw_y: public_key_raw_y, public_key_y: public_key_y}
end

def create_unknown_network_address
  public_key = Wallet.create_key_pair[:public_key]
  prefix = "U0"
  raw_address = (public_key.x + public_key.y).to_s(base: 16)
  hashed_address = ripemd160(sha256(raw_address).hexstring).hexstring
  version_address = prefix + hashed_address
  hashed_address_again = sha256(sha256(version_address).hexstring).hexstring
  checksum = hashed_address_again[0..5]
  Base64.strict_encode(version_address + checksum)
end
