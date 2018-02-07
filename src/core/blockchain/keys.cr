module ::Sushi::Core::Keys
  include Hashes
  include Sushi::Core::Models

  class Keys
    property private_key : PrivateKey
    property public_key : PublicKey

    def initialize(@private_key : PrivateKey, @public_key : PublicKey)
    end

    def self.generate(network : Network = {prefix: "M0", name: "mainnet"})
      secp256k1 = ECDSA::Secp256k1.new
      key_pair = secp256k1.create_key_pair
      private_key = PrivateKey.new(key_pair[:secret_key].to_s(16), network)
      public_key = PublicKey.new(key_pair[:public_key].x.to_s(16) + key_pair[:public_key].y.to_s(16), network)
      Keys.new(private_key, public_key)
    end
  end

  class PublicKey
    getter network : Network

    def initialize(hex : String, @network : Network = {prefix: "M0", name: "mainnet"})
      @hex = hex
      raise "Invalid public key: #{@hex}" unless is_valid?
    end

    def self.from(hex : String, network : Network = {prefix: "M0", name: "mainnet"}) : PublicKey
      PublicKey.new(hex, network)
    end

    def self.from(bytes : Bytes, network : Network = {prefix: "M0", name: "mainnet"}) : PublicKey
      PublicKey.new(to_hex(bytes), network)
    end

    def as_hex : String
      @hex
    end

    def as_bytes : Bytes
      to_bytes(@hex)
    end

    def address : String
      get_address_from_public_key(self)
    end

    def is_valid? : Bool
      @hex.hexbytes? != nil && @hex.size == 128
    end
  end

  class PrivateKey
    getter network : Network

    def initialize(hex : String, @network : Network = {prefix: "M0", name: "mainnet"})
      @hex = hex
      raise "Invalid private key: #{@hex}" unless is_valid?
    end

    def self.from(hex : String, network : Network = {prefix: "M0", name: "mainnet"}) : PrivateKey
      PrivateKey.new(hex, network)
    end

    def self.from(bytes : Bytes, network : Network = {prefix: "M0", name: "mainnet"}) : PrivateKey
      PrivateKey.new(to_hex(bytes), network)
    end

    def as_hex : String
      @hex
    end

    def as_bytes : Bytes
      to_bytes(@hex)
    end

    def wif : Wif
    end

    def public_key : PublicKey
      secp256k1 = ECDSA::Secp256k1.new
      key_pair = secp256k1.create_key_pair(@hex.to_big_i(16))

      raise "Private key mismatch when finding public key" unless key_pair[:secret_key].to_s(16) == @hex

      PublicKey.new(key_pair[:public_key].x.to_s(16) + key_pair[:public_key].y.to_s(16), @network)
    end

    def address : String
      get_address_from_public_key(self.public_key)
    end

    def is_valid? : Bool
      @hex.hexbytes? != nil && @hex.size == 64
    end
  end

  class Wif
    def initialize(private_key : PrivateKey, network : Network)
      @wif = to_wif(private_key, network)
    end

    def self.from(private_key : PrivateKey, network : Network) : Wif
      Wif.new(private_key, network)
    end

    def self.from(wif : String) : Wif
    end

    def private_key : PrivateKey
    end

    def public_key : PublicKey
    end

    def network : Network
    end

    def address : String
    end

    private def to_wif(private_key : PrivateKey, network : Network = {prefix: "M0", name: "mainnet"}) : Wif
    end
  end

  def to_hex(bytes : Bytes) : String
    bytes.to_unsafe.to_slice(bytes.size).hexstring
  end

  def to_bytes(hex : String) : Bytes
    hex.hexbytes
  end

  def get_address_from_public_key(public_key : PublicKey)
    hashed_address = ripemd160(sha256(public_key.as_hex))
    network_address = public_key.network[:prefix] + hashed_address
    hashed_address_again = sha256(sha256(network_address))
    checksum = hashed_address_again[0..5]
    Base64.strict_encode(network_address + checksum)
  end
end
