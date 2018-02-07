module ::Sushi::Core::Keys
  include Hashes
  include Sushi::Core::Models

  class Keys
    getter private_key : PrivateKey
    getter public_key : PublicKey
    getter wif : Wif
    getter address : Address

    def initialize(@private_key : PrivateKey, @public_key : PublicKey, @wif : Wif, @address : Address)
    end

    def self.generate(network : Network = {prefix: "M0", name: "mainnet"})
      secp256k1 = ECDSA::Secp256k1.new
      key_pair = secp256k1.create_key_pair
      private_key = PrivateKey.new(key_pair[:secret_key].to_s(16), network)
      public_key = PublicKey.new(key_pair[:public_key].x.to_s(16) + key_pair[:public_key].y.to_s(16), network)
      Keys.new(private_key, public_key, private_key.wif, public_key.address)
    end
  end

  class Address
    getter network

    def initialize(hex_address : String, @network : Network = {prefix: "M0", name: "mainnet"})
      @hex = hex_address
    end

    def as_hex
      @hex
    end
  end

  class PublicKey
    getter network : Network

    def initialize(public_key_hex : String, @network : Network = {prefix: "M0", name: "mainnet"})
      @hex = public_key_hex
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

    def address : Address
      Address.new(get_address_from_public_key(self), @network)
    end

    def is_valid? : Bool
      @hex.hexbytes? != nil && @hex.size == 128
    end
  end

  class PrivateKey
    getter network : Network

    def initialize(private_key_hex : String, @network : Network = {prefix: "M0", name: "mainnet"})
      @hex = private_key_hex
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
      Wif.from(self, @network)
    end

    def public_key : PublicKey
      secp256k1 = ECDSA::Secp256k1.new
      key_pair = secp256k1.create_key_pair(@hex.to_big_i(16))

      raise "Private key mismatch when finding public key" unless key_pair[:secret_key].to_s(16) == @hex

      PublicKey.new(key_pair[:public_key].x.to_s(16) + key_pair[:public_key].y.to_s(16), @network)
    end

    def address : Address
      Address.new(get_address_from_public_key(self.public_key), @network)
    end

    def is_valid? : Bool
      @hex.hexbytes? != nil && @hex.size == 64
    end
  end

  class Wif
    def initialize(wif_hex : String)
      @hex = wif_hex
      raise "Invalid wif: #{@hex}" unless is_valid?
    end

    def as_hex
      @hex
    end

    def self.from(private_key : PrivateKey, network : Network = {prefix: "M0", name: "mainnet"}) : Wif
      to_wif(private_key, network)
    end

    def private_key : PrivateKey
      from_wif(self)[:private_key]
    end

    def public_key : PublicKey
      from_wif(self)[:private_key].public_key
    end

    def network : Network
      from_wif(self)[:network]
    end

    def address : Address
      res = from_wif(self)
      public_key = res[:private_key].public_key
      network = res[:network]
      Address.new(get_address_from_public_key(public_key), network)
    end

    def is_valid? : Bool
      decoded_wif = Base64.decode_string(@hex)
      network_key = decoded_wif[0..-7]
      hashed_key = sha256(sha256(network_key))
      checksum = hashed_key[0..5]
      checksum == decoded_wif[-6..-1]
    rescue e : Exception
      false
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

  def to_wif(key : PrivateKey, network : Network) : Wif
    private_key = key.as_hex
    network_key = network[:prefix] + private_key
    hashed_key = sha256(sha256(network_key))
    checksum = hashed_key[0..5]
    encoded_key = Base64.strict_encode(network_key + checksum)
    Wif.new(encoded_key)
  end

  def from_wif(wif : Wif) : {private_key: PrivateKey, network: Network}
    decoded_wif = Base64.decode_string(wif.as_hex)
    network_prefix = decoded_wif[0..1]
    network = network_prefix == "M0" ? {prefix: "M0", name: "mainnet"} : {prefix: "T0", name: "testnet"}
    private_key_hex = decoded_wif[2..-7]
    private_key = PrivateKey.from(private_key_hex)
    {private_key: private_key, network: network}
  end
end
