module ::Sushi::Core
  class Wallet
    extend Hashes

    MAINNET = { prefix: "M0", name: "mainnet" }
    TESTNET = { prefix: "T0", name: "testnet" }

    JSON.mapping({
                   secret_key: String,
                   public_key_x: String,
                   public_key_y: String,
                   address: String,
                 })

    getter secret_key : String
    getter public_key_x : String
    getter public_key_y : String
    getter address : String

    def initialize(@secret_key : String, @public_key_x : String, @public_key_y : String, @address : String)
    end

    def verify!
      Wallet.verify!(@secret_key, @public_key_x, @public_key_y, @address)
    end

    def self.from_path(wallet_path : String) : self
      raise "Failed to find wallet at #{wallet_path}, create it first!" unless File.exists?(wallet_path)

      self.from_json(File.read(wallet_path))
    end

    def self.create(testnet = false)
      key_pair = create_key_pair
      address = public_key_to_address(key_pair[:public_key], testnet)

      {
        secret_key: Base64.strict_encode(key_pair[:secret_key].to_s(base: 10)),
        public_key_x: Base64.strict_encode(key_pair[:public_key].x.to_s(base: 10)),
        public_key_y: Base64.strict_encode(key_pair[:public_key].y.to_s(base: 10)),
        address: address
      }
    end

    def self.create_key_pair
      secp256k1 = ECDSA::Secp256k1.new
      key_pair = secp256k1.create_key_pair

      {
        secret_key: key_pair[:secret_key],
        public_key: key_pair[:public_key],
      }
    end

    def self.verify!(secret_key : String,
                     public_key_x : String,
                     public_key_y : String,
                     address : String) : Bool
      secp256k1 = ECDSA::Secp256k1.new
      secret_key_raw = BigInt.new(Base64.decode_string(secret_key), base: 10)
      public_key_raw_x = BigInt.new(Base64.decode_string(public_key_x), base: 10)
      public_key_raw_y = BigInt.new(Base64.decode_string(public_key_y), base: 10)

      raise "Invalid checksum for #{address}" unless valid_checksum?(address)

      public_key = secp256k1.create_key_pair(secret_key_raw)[:public_key]
      public_key_x = public_key.x.to_s(base: 10)
      public_key_y = public_key.y.to_s(base: 10)

      raise "Invalid public key for #{public_key_raw_x} != #{public_key_x}" unless public_key_raw_x != public_key_x
      raise "Invalid public key for #{public_key_raw_y} != #{public_key_y}" unless public_key_raw_y != public_key_y

      true
    end

    def self.public_key_to_address(public_key : ECDSA::Point, testnet = false) : String
      prefix = testnet ? TESTNET[:prefix] : MAINNET[:prefix]
      raw_address = (public_key.x + public_key.y).to_s(base: 16)
      hashed_address = ripemd160(sha256(raw_address).hexstring).hexstring
      version_address = prefix + hashed_address
      hashed_address_again = sha256(sha256(version_address).hexstring).hexstring
      checksum = hashed_address_again[0..5]
      Base64.strict_encode(version_address + checksum)
    end

    def self.valid_checksum?(address : String) : Bool
      decoded_address = Base64.decode_string(address)
      return false unless decoded_address.size == 48
      version_address = decoded_address[0..-7]
      hashed_address = sha256(sha256(version_address).hexstring).hexstring
      checksum = decoded_address[-6..-1]
      checksum == hashed_address[0..5]
    end

    def self.address_network_type(address : String) : Models::Network
      raise "Invalid checksum for the address: #{address}" unless valid_checksum?(address)

      decoded_address = Base64.decode_string(address)

      case decoded_address[0..1]
      when MAINNET[:prefix]
        MAINNET
      when TESTNET[:prefix]
        TESTNET
      else
        raise "Invalid network: #{decoded_address[0..1]}"
      end
    end

    include Hashes
  end
end

