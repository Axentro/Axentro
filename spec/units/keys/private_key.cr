# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "./../../spec_helper"
require "./../utils"

include Sushi::Core
include Sushi::Core::Keys

describe PrivateKey do
  describe "#initialize" do
    it "should create a private key object from a private key string" do
      key_pair = ECCrypto.create_key_pair
      hex_private_key = key_pair[:hex_private_key]

      private_key = PrivateKey.new(hex_private_key)
      private_key.as_hex.should eq(hex_private_key)
    end

    it "should raise an error if the private key hex string is not a valid private key" do
      expect_raises(Exception, "invalid private key: 123") do
        PrivateKey.new("123")
      end
    end
  end

  describe "#from hex" do
    it "should create a private key object from a private key string" do
      key_pair = ECCrypto.create_key_pair
      hex_private_key = key_pair[:hex_private_key]

      private_key = PrivateKey.from(hex_private_key)
      private_key.as_hex.should eq(hex_private_key)
    end
  end

  describe "#from bytes" do
    it "should create a private key object from a private key byte array" do
      key_pair = ECCrypto.create_key_pair
      hex_private_key = key_pair[:hex_private_key]
      hexbytes = hex_private_key.hexbytes

      private_key = PrivateKey.from(hexbytes)
      private_key.as_bytes.should eq(hexbytes)
      private_key.as_hex.should eq(hex_private_key)
    end
  end

  it "should convert a private key from hex to bytes with #as_bytes" do
    key_pair = ECCrypto.create_key_pair
    hex_private_key = key_pair[:hex_private_key]
    hexbytes = hex_private_key.hexbytes

    private_key = PrivateKey.from(hex_private_key)
    private_key.as_bytes.should eq(hexbytes)
  end

  it "should convert a private key from bytes to hex with #as_hex" do
    key_pair = ECCrypto.create_key_pair
    hex_private_key = key_pair[:hex_private_key]
    hexbytes = hex_private_key.hexbytes

    private_key = PrivateKey.from(hexbytes)
    private_key.as_hex.should eq(hex_private_key)
  end

  describe "#network" do
    it "should return the mainnet by default" do
      KeyRing.generate.private_key.network.should eq(MAINNET)
    end
    it "should return the supplied network" do
      KeyRing.generate(TESTNET).private_key.network.should eq(TESTNET)
    end
  end

  describe "#address" do
    it "should return the address" do
      hex_private_key = "e70f8fef23401466cebd0d9c51d5740f98cbc6694ae60b09c945ba6b67dbec8d"

      private_key = PrivateKey.from(hex_private_key)
      private_key.address.as_hex.should eq("TTBkYjYyZGZiZWM3ZWJlNjllYjJhYTQyMGQ2ZmNhOWMwZGU4ZDQwNmI5YjM4YTUx")
    end

    it "should return a mainnet address" do
      keys = KeyRing.generate
      decoded_address = Base64.decode_string(keys.private_key.address.as_hex)
      decoded_address[0..1].should eq("M0")
    end

    it "should return a testnet address" do
      keys = KeyRing.generate(TESTNET)
      decoded_address = Base64.decode_string(keys.private_key.address.as_hex)
      decoded_address[0..1].should eq("T0")
    end
  end

  describe "#is_valid?" do
    it "should return true if the public key is valid" do
      KeyRing.generate.private_key.is_valid?.should be_true
    end
  end
  STDERR.puts "< Keys::PrivateKey"
end
