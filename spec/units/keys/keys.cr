require "./../../spec_helper"
require "./../utils"

include Sushi::Core
include Sushi::Core::Keys

describe Keys do
  describe "#Keys.generate" do
    it "should generate a private and public key pair as Key objects" do
      keys = Keys.generate

      keys.private_key.should be_a(PrivateKey)
      keys.private_key.as_hex.size.should eq(64)

      keys.public_key.should be_a(PublicKey)
      keys.public_key.as_hex.size.should eq(128)
    end

    it "should generate a key pair for the mainnet when no network supplied" do
      keys = Keys.generate
      keys.public_key.network.should eq(MAINNET)
    end

    it "should generate a key pair for the specified network" do
      keys = Keys.generate(TESTNET)
      keys.public_key.network.should eq(TESTNET)
    end

    it "should make a wif for mainnet when no network supplied" do
      keys = Keys.generate
      keys.wif.network.should eq(MAINNET)
    end

    it "should make a wif for the specified network" do
      keys = Keys.generate(TESTNET)
      keys.wif.network.should eq(TESTNET)
    end

    it "should make an address for mainnet when no network supplied" do
      keys = Keys.generate
      keys.address.network.should eq(MAINNET)
    end

    it "should make an address for the specified network" do
      keys = Keys.generate(TESTNET)
      keys.address.network.should eq(TESTNET)
    end
  end

  STDERR.puts "< Keys"
end
