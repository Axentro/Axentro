require "./../../spec_helper"
require "./../utils"

include Sushi::Core
include Sushi::Core::Keys

describe Wif do
  describe "#initialize" do
    it "should create a wif key object from a wif hex string" do
      wif_hex = "TTA4YWM5MzAzYjIxZWYyMjU3M2Q3ODQ0ZmFlNDI1ZjdmMGYxOTNjMzIyNjBiYzVmMzQ0MTUxMjA4ZmI1MzAzNTk0NTJiOWNi"
      Wif.new(wif_hex).as_hex.should eq(wif_hex)
    end

    it "should raise an error if the private key hex string is not a valid private key" do
      expect_raises(Exception, "Invalid wif: 123") do
        Wif.new("123")
      end
    end
  end

  describe "#from hex" do
    it "should create a wif object from a private key string" do
      hex_private_key = "f92913f355539a6ec6129b744a9e1dcb4d3c8df29cccb8066d57c454cead6fe4"

      wif = PrivateKey.from(hex_private_key).wif
      wif.as_hex.should eq("TTBmOTI5MTNmMzU1NTM5YTZlYzYxMjliNzQ0YTllMWRjYjRkM2M4ZGYyOWNjY2I4MDY2ZDU3YzQ1NGNlYWQ2ZmU0MjdlYzNl")
    end
  end

  it "should return the public key when calling #public_key" do
    keys = Keys.generate
    keys.wif.public_key.as_hex.should eq(keys.public_key.as_hex)
  end

  it "should return the private key when calling #private_key" do
    keys = Keys.generate
    keys.wif.private_key.as_hex.should eq(keys.private_key.as_hex)
  end

  describe "#network" do
    it "should return the mainnet by default" do
      Keys.generate.wif.network.should eq({prefix: "M0", name: "mainnet"})
    end
    it "should return the supplied network" do
      Keys.generate({prefix: "T0", name: "testnet"}).wif.network.should eq({prefix: "T0", name: "testnet"})
    end
  end

  describe "#address" do
    it "should return the address" do
      hex_private_key = "5509e2f567bbe25ef90d2682e3fed09266117ce493438a3c20c05b34293a29a6"
      private_key = PrivateKey.from(hex_private_key)

      wif = private_key.wif
      wif.address.as_hex.should eq("TTA0YTQzZDQ1M2UwNzdlZDA5YTI1NGYxZGNiNTNhYmY0OTE4NmEyMzg5YTJmMGI0")
    end
  end

  describe "#is_valid?" do
    it "should return true if the wif is valid" do
      # See comment on PublicKey #is_valid? same applies here
      Keys.generate.wif.is_valid?.should be_true
    end
  end
  STDERR.puts "< Keys::Wif"
end
