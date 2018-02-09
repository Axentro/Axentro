module ::Sushi::Core::Keys
  include Sushi::Core::Models

  class PublicKey
    getter network : Network

    def initialize(public_key_hex : String, @network : Network = MAINNET)
      @hex = public_key_hex
      raise "Invalid public key: #{@hex}" unless is_valid?
    end

    def self.from(hex : String, network : Network = MAINNET) : PublicKey
      PublicKey.new(hex, network)
    end

    def self.from(bytes : Bytes, network : Network = MAINNET) : PublicKey
      PublicKey.new(KeyUtils.to_hex(bytes), network)
    end

    def as_hex : String
      @hex
    end

    def as_bytes : Bytes
      KeyUtils.to_bytes(@hex)
    end

    def address : Address
      Address.new(KeyUtils.get_address_from_public_key(self), @network)
    end

    def is_valid? : Bool
      @hex.hexbytes? != nil && @hex.size == 128
    end
  end
end
