# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "./../../spec_helper"

include Axentro::Core
include Axentro::Core::Keys

describe PublicKey do
  describe "#initialize" do
    it "should create a public key object from a public key string" do
      key_pair = KeyUtils.create_new_keypair
      hex_public_key = key_pair[:hex_public_key]

      public_key = PublicKey.new(hex_public_key)
      public_key.as_hex.should eq(hex_public_key)
    end

    it "should raise an error if the public key hex string is not a valid public key" do
      expect_raises(Exception, "invalid public key: 123") do
        PublicKey.new("123")
      end
    end
  end

  describe "#from hex" do
    it "should create a public key object from a public key string" do
      key_pair = KeyUtils.create_new_keypair
      hex_public_key = key_pair[:hex_public_key]

      public_key = PublicKey.from(hex_public_key)
      public_key.as_hex.should eq(hex_public_key)
    end
  end

  describe "#from bytes" do
    it "should create a public key object from a public key byte array" do
      key_pair = KeyUtils.create_new_keypair
      hex_public_key = key_pair[:hex_public_key]
      hexbytes = hex_public_key.hexbytes

      public_key = PublicKey.from(hexbytes)
      public_key.as_bytes.should eq(hexbytes)
      public_key.as_hex.should eq(hex_public_key)
    end
    it "should raise an error if the public key byte array is not a valid public key" do
    end
  end

  it "should convert a public key from hex to bytes with #as_bytes" do
    key_pair = KeyUtils.create_new_keypair
    hex_public_key = key_pair[:hex_public_key]
    hexbytes = hex_public_key.hexbytes

    public_key = PublicKey.from(hex_public_key)
    public_key.as_bytes.should eq(hexbytes)
  end

  it "should convert a public key from bytes to hex with #as_hex" do
    key_pair = KeyUtils.create_new_keypair
    hex_public_key = key_pair[:hex_public_key]
    hexbytes = hex_public_key.hexbytes

    public_key = PublicKey.from(hexbytes)
    public_key.as_hex.should eq(hex_public_key)
  end

  describe "#network" do
    it "should return the mainnet by default" do
      KeyRing.generate.public_key.network.should eq(MAINNET)
    end
    it "should return the supplied network" do
      KeyRing.generate(TESTNET).public_key.network.should eq(TESTNET)
    end
  end

  describe "#address" do
    it "should return the address" do
      hex_public_key = "bf668c4c446d540452f47b4c10ff85235f5aedb088a90eba8af59cf982489373"

      public_key = PublicKey.from(hex_public_key)
      public_key.address.as_hex.should eq("TTA5OGFmMWM5MzEzOTg4OWVjNGMyNjVmNmY1ZWMwMzhlN2M3ZWMwZGFkZjdhYWU0")
    end

    it "should return a mainnet address" do
      keys = KeyRing.generate
      decoded_address = Base64.decode_string(keys.public_key.address.as_hex)
      decoded_address[0..1].should eq("M0")
    end

    it "should return a testnet address" do
      keys = KeyRing.generate(TESTNET)
      decoded_address = Base64.decode_string(keys.public_key.address.as_hex)
      decoded_address[0..1].should eq("T0")
    end
  end

  describe "#is_valid?" do
    it "should return true if the public key is valid" do
      KeyRing.generate.public_key.is_valid?.should be_true
    end
  end
end
