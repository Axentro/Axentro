module ::Sushi::Core::Keys
  include Sushi::Core::Models

  class PrivateKey
    getter network : Network

    def initialize(private_key_hex : String, @network : Network = MAINNET)
      @hex = private_key_hex
      raise "Invalid private key: #{@hex}" unless is_valid?
    end

    def self.from(hex : String, network : Network = MAINNET) : PrivateKey
      PrivateKey.new(hex, network)
    end

    def self.from(bytes : Bytes, network : Network = MAINNET) : PrivateKey
      PrivateKey.new(KeyUtils.to_hex(bytes), network)
    end

    def as_hex : String
      @hex
    end

    def as_bytes : Bytes
      KeyUtils.to_bytes(@hex)
    end

    def as_big_i : BigInt
      @hex.to_big_i(16)
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
      Address.new(KeyUtils.get_address_from_public_key(self.public_key), @network)
    end

    def is_valid? : Bool
      @hex.hexbytes? != nil && @hex.size == 64
    end
  end
end
