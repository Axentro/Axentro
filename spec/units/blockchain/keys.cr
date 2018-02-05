require "./../../spec_helper"
require "./../utils"

include Sushi::Core
include Sushi::Core::Keys

describe Keys do
  describe PublicKey do
    describe "#initialize" do
      it "should create a public key object from a public key string" do
        public_key = PublicKey.new("")
      end

      it "should raise an error if the public key string is not a valid public key" do
      end
    end

    describe "#from hex" do
      it "should create a public key object from a public key string" do
      end
    end

    describe "#from bytes" do
      it "should create a public key object from a public key byte array" do
      end
      it "should raise an error if the public key byte array is not a valid public key" do
      end
    end

    it "should convert a public key from hex to bytes with #as_bytes" do
    end

    it "should convert a public key from bytes to hex with #as_hex" do
    end

    it "should return the address with #address" do
    end

    describe "#is_valid?" do
      it "should return true if the public key is valid" do
      end
      it "should return false if the public key is invalid" do
      end
    end
  end
end
