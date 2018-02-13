require "./../../spec_helper"
require "./../utils"

include Sushi::Core
include Hashes

describe Wallet do

  password = "passwordpassword"

  describe "create new wallet" do
    it "should create a new wallet on the testnet" do
      wallet = Wallet.from_json(Wallet.create(true).to_json)
      Wallet.verify!(wallet.private_key, wallet.public_key, wallet.wif, wallet.address).should be_true
      Wallet.address_network_type(wallet.address).should eq({prefix: "T0", name: "testnet"})
    end

    it "should create a new wallet on the mainnet" do
      wallet = Wallet.from_json(Wallet.create(false).to_json)
      Wallet.verify!(wallet.private_key, wallet.public_key, wallet.wif, wallet.address).should be_true
      Wallet.address_network_type(wallet.address).should eq({prefix: "M0", name: "mainnet"})
    end
  end

  describe "verify wallet" do
    it "should verify a valid wallet" do
      wallet = Wallet.from_json(Wallet.create(false).to_json)
      Wallet.verify!(wallet.private_key, wallet.public_key, wallet.wif, wallet.address).should be_true
    end

    it "should verify a valid wallet using the instance method verify!" do
      wallet = Wallet.from_json(Wallet.create(false).to_json)
      wallet.verify!.should be_true
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

    it "should raise an invalid network error when address not mainnet or testnet" do
      expect_raises(Exception, /Invalid network: U0/) do
        Wallet.address_network_type(create_unknown_network_address)
      end
    end
  end

  describe "#from_path" do
    it "should find a wallet from the supplied path" do
      test_wallet_0 = "#{__DIR__}/../../../wallets/testnet-0.json"
      wallet = Wallet.from_path(test_wallet_0)
      Wallet.verify!(wallet.private_key, wallet.public_key, wallet.wif, wallet.address).should be_true
    end

    it "should raise a wallet not found error when no wallet file exists at the specific path" do
      expect_raises(Exception, "Failed to find wallet at invalid-path, create it first!") do
        Wallet.from_path("invalid-path")
      end
    end
  end

  STDERR.puts "< Wallet"
end

def create_unknown_network_address
  secp256k1 = ECDSA::Secp256k1.new
  public_key = secp256k1.create_key_pair[:public_key]
  prefix = "U0"
  raw_address = (public_key.x + public_key.y).to_s(base: 16)
  hashed_address = ripemd160(sha256(raw_address))
  version_address = prefix + hashed_address
  hashed_address_again = sha256(sha256(version_address))
  checksum = hashed_address_again[0..5]
  Base64.strict_encode(version_address + checksum)
end
