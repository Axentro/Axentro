require "./../../spec_helper"
require "./../utils"

include Sushi::Core
include Sushi::Core::Keys

describe Keys do
  describe PublicKey do
    describe "#initialize" do
      it "should create a public key object from a public key string" do
        secp256k1 = ECDSA::Secp256k1.new
        key_pair = secp256k1.create_key_pair
        hex_public_key = key_pair[:public_key].x.to_s(16) + key_pair[:public_key].y.to_s(16)

        public_key = PublicKey.new(hex_public_key)
        public_key.as_hex.should eq(hex_public_key)
      end

      it "should raise an error if the public key string is not a valid public key" do
      end
    end

    describe "#from hex" do
      it "should create a public key object from a public key string" do
        secp256k1 = ECDSA::Secp256k1.new


         loop do
             key_pair = secp256k1.create_key_pair
             one = key_pair[:public_key].x.to_s(16)
             p two = key_pair[:public_key].y.to_s(16)
             sk = key_pair[:secret_key].to_s(16)
             # p sk.size
             # p one.size
             # p two.size
            hex_public_key = one + two
            if hex_public_key.hexbytes? == nil
              puts "is not hex: #{hex_public_key}"
              break
            end
         end

        # public_key = PublicKey.from(hex_public_key)
        # public_key.as_hex.should eq(hex_public_key)
      end
    end

    describe "#from bytes" do
      it "should create a public key object from a public key byte array" do
        secp256k1 = ECDSA::Secp256k1.new
        key_pair = secp256k1.create_key_pair
        hex_public_key = key_pair[:public_key].x.to_s(16) + key_pair[:public_key].y.to_s(16)
        hexbytes = hex_public_key.hexbytes
        # p typeof(hexbytes)
        public_key = PublicKey.from(hexbytes)
        public_key.as_bytes.should eq(hexbytes)
        public_key.as_hex.should eq(hex_public_key)
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
