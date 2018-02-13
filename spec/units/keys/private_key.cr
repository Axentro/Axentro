require "./../../spec_helper"
require "./../utils"

include Sushi::Core
include Sushi::Core::Keys

describe PrivateKey do
  describe "#initialize" do
    it "should create a private key object from a private key string" do
      secp256k1 = ECDSA::Secp256k1.new
      key_pair = secp256k1.create_key_pair
      hex_private_key = key_pair[:secret_key].to_s(16)

      private_key = PrivateKey.new(hex_private_key)
      private_key.as_hex.should eq(hex_private_key)
    end

    it "should raise an error if the private key hex string is not a valid private key" do
      expect_raises(Exception, "Invalid private key: 123") do
        PrivateKey.new("123")
      end
    end
  end

  describe "#from hex" do
    it "should create a private key object from a private key string" do
      secp256k1 = ECDSA::Secp256k1.new
      key_pair = secp256k1.create_key_pair
      hex_private_key = key_pair[:secret_key].to_s(16)

      private_key = PrivateKey.from(hex_private_key)
      private_key.as_hex.should eq(hex_private_key)
    end
  end

  describe "#from bytes" do
    it "should create a private key object from a private key byte array" do
      secp256k1 = ECDSA::Secp256k1.new
      key_pair = secp256k1.create_key_pair
      hex_private_key = key_pair[:secret_key].to_s(16)
      hexbytes = hex_private_key.hexbytes

      private_key = PrivateKey.from(hexbytes)
      private_key.as_bytes.should eq(hexbytes)
      private_key.as_hex.should eq(hex_private_key)
    end
  end

  it "should convert a private key from hex to bytes with #as_bytes" do
    secp256k1 = ECDSA::Secp256k1.new
    key_pair = secp256k1.create_key_pair
    hex_private_key = key_pair[:secret_key].to_s(16)
    hexbytes = hex_private_key.hexbytes

    private_key = PrivateKey.from(hex_private_key)
    private_key.as_bytes.should eq(hexbytes)
  end

  it "should convert a private key from bytes to hex with #as_hex" do
    secp256k1 = ECDSA::Secp256k1.new
    key_pair = secp256k1.create_key_pair
    hex_private_key = key_pair[:secret_key].to_s(16)
    hexbytes = hex_private_key.hexbytes

    private_key = PrivateKey.from(hexbytes)
    private_key.as_hex.should eq(hex_private_key)
  end

  describe "#network" do
    it "should return the mainnet by default" do
      Keys.generate.private_key.network.should eq(MAINNET)
    end
    it "should return the supplied network" do
      Keys.generate(TESTNET).private_key.network.should eq(TESTNET)
    end
  end

  describe "#address" do
    it "should return the address" do
      hex_private_key = "5509e2f567bbe25ef90d2682e3fed09266117ce493438a3c20c05b34293a29a6"

      private_key = PrivateKey.from(hex_private_key)
      private_key.address.as_hex.should eq("TTA0YTQzZDQ1M2UwNzdlZDA5YTI1NGYxZGNiNTNhYmY0OTE4NmEyMzg5YTJmMGI0")
    end

    it "should return a mainnet address" do
      keys = Keys.generate
      decoded_address = Base64.decode_string(keys.private_key.address.as_hex)
      decoded_address[0..1].should eq("M0")
    end

    it "should return a testnet address" do
      keys = Keys.generate(TESTNET)
      decoded_address = Base64.decode_string(keys.private_key.address.as_hex)
      decoded_address[0..1].should eq("T0")
    end
  end

  describe "#is_valid?" do
    it "should return true if the public key is valid" do
      Keys.generate.private_key.is_valid?.should be_true
    end
  end
  STDERR.puts "< Keys::PrivateKey"
end
