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
      keys.public_key.network.should eq({prefix: "M0", name: "mainnet"})
    end

    it "should generate a key pair for the specified network" do
      keys = Keys.generate({prefix: "T0", name: "testnet"})
      keys.public_key.network.should eq({prefix: "T0", name: "testnet"})
    end
  end

  describe PublicKey do
    describe "#initialize" do
      it "should create a public key object from a public key string" do
        secp256k1 = ECDSA::Secp256k1.new
        key_pair = secp256k1.create_key_pair
        hex_public_key = key_pair[:public_key].x.to_s(16) + key_pair[:public_key].y.to_s(16)

        public_key = PublicKey.new(hex_public_key)
        public_key.as_hex.should eq(hex_public_key)
      end

      it "should raise an error if the public key hex string is not a valid public key" do
        expect_raises(Exception, "Invalid public key: 123") do
          PublicKey.new("123")
        end
      end
    end

    describe "#from hex" do
      it "should create a public key object from a public key string" do
        secp256k1 = ECDSA::Secp256k1.new
        key_pair = secp256k1.create_key_pair
        hex_public_key = key_pair[:public_key].x.to_s(16) + key_pair[:public_key].y.to_s(16)

        public_key = PublicKey.from(hex_public_key)
        public_key.as_hex.should eq(hex_public_key)
      end
    end

    describe "#from bytes" do
      it "should create a public key object from a public key byte array" do
        secp256k1 = ECDSA::Secp256k1.new
        key_pair = secp256k1.create_key_pair
        hex_public_key = key_pair[:public_key].x.to_s(16) + key_pair[:public_key].y.to_s(16)
        hexbytes = hex_public_key.hexbytes

        public_key = PublicKey.from(hexbytes)
        public_key.as_bytes.should eq(hexbytes)
        public_key.as_hex.should eq(hex_public_key)
      end
      it "should raise an error if the public key byte array is not a valid public key" do
      end
    end

    it "should convert a public key from hex to bytes with #as_bytes" do
      secp256k1 = ECDSA::Secp256k1.new
      key_pair = secp256k1.create_key_pair
      hex_public_key = key_pair[:public_key].x.to_s(16) + key_pair[:public_key].y.to_s(16)
      hexbytes = hex_public_key.hexbytes

      public_key = PublicKey.from(hex_public_key)
      public_key.as_bytes.should eq(hexbytes)
    end

    it "should convert a public key from bytes to hex with #as_hex" do
      secp256k1 = ECDSA::Secp256k1.new
      key_pair = secp256k1.create_key_pair
      hex_public_key = key_pair[:public_key].x.to_s(16) + key_pair[:public_key].y.to_s(16)
      hexbytes = hex_public_key.hexbytes

      public_key = PublicKey.from(hexbytes)
      public_key.as_hex.should eq(hex_public_key)
    end

    describe "#network" do
      it "should return the mainnet by default" do
        Keys.generate.public_key.network.should eq({prefix: "M0", name: "mainnet"})
      end
      it "should return the supplied network" do
        Keys.generate({prefix: "T0", name: "testnet"}).public_key.network.should eq({prefix: "T0", name: "testnet"})
      end
    end

    describe "#address" do
      it "should return the address" do
        hex_public_key = "b9a152547ec31de50a726896293c7b99e63e6d9588b6d48fde5c926a1794d0616af3598724f335ec71b00509a69e3ce376a285ca5dd77ed5cce8e558c9d5b7e7"

        public_key = PublicKey.from(hex_public_key)
        public_key.address.should eq("TTA5YjVkYTA1NWVkNWQyNDYyMmNiMWU5M2EwZWVhZmFmODA4MDg3MjU5NzAxNTll")
      end

      it "should return a mainnet address" do
        keys = Keys.generate
        decoded_address = Base64.decode_string(keys.public_key.address)
        decoded_address[0..1].should eq("M0")
      end

      it "should return a testnet address" do
        keys = Keys.generate({prefix: "T0", name: "testnet"})
        decoded_address = Base64.decode_string(keys.public_key.address)
        decoded_address[0..1].should eq("T0")
      end
    end

    describe "#is_valid?" do
      it "should return true if the public key is valid" do
        # will always be true when called externally since we raise an error creating a public key with an invalid hex
        # however when called internally we use this to determine if the supplied hex is valid when creating a public key
        # so we can't test the false condition here.
        Keys.generate.public_key.is_valid?.should be_true
      end
    end
  end

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
        Keys.generate.private_key.network.should eq({prefix: "M0", name: "mainnet"})
      end
      it "should return the supplied network" do
        Keys.generate({prefix: "T0", name: "testnet"}).private_key.network.should eq({prefix: "T0", name: "testnet"})
      end
    end

    describe "#address" do
      it "should return the address" do
        hex_private_key = "5509e2f567bbe25ef90d2682e3fed09266117ce493438a3c20c05b34293a29a6"

        private_key = PrivateKey.from(hex_private_key)
        private_key.address.should eq("TTA0YTQzZDQ1M2UwNzdlZDA5YTI1NGYxZGNiNTNhYmY0OTE4NmEyMzg5YTJmMGI0")
      end

      it "should return a mainnet address" do
        keys = Keys.generate
        decoded_address = Base64.decode_string(keys.private_key.address)
        decoded_address[0..1].should eq("M0")
      end

      it "should return a testnet address" do
        keys = Keys.generate({prefix: "T0", name: "testnet"})
        decoded_address = Base64.decode_string(keys.private_key.address)
        decoded_address[0..1].should eq("T0")
      end
    end

    describe "#is_valid?" do
      it "should return true if the public key is valid" do
        # See comment on PublicKey #is_valid? same applies here
        Keys.generate.private_key.is_valid?.should be_true
      end
    end
  end
    STDERR.puts "< Keys"
end
