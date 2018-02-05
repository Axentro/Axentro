module ::Sushi::Core::Keys
  extend Hashes

  class PublicKey

    def initialize(hex : String)
      @hex = hex
    end

    def self.from(hex : String) : PublicKey
      PublicKey.new(hex)
    end

    def self.from(bytes : Array(UInt8)) : PublicKey
      PublicKey.new(to_hex(bytes))
    end

    def as_hex : String
      @hex
    end

    def as_bytes : Array(UInt8)
      to_bytes(@hex)
    end

    def address : String
    end

    def is_valid? : Bool
    end

  end

  class PrivateKey

    def initialize(hex : String)
      @hex = hex
    end

    def self.from(hex : String) : PrivateKey
      PrivateKey.new(hex)
    end

    def self.from(bytes : Array(UInt8)) : PrivateKey
        PrivateKey.new(to_hex(bytes))
    end

    def as_hex : String
      @hex
    end

    def as_bytes : Array(UInt8)
      to_bytes(@hex)
    end

    def wif : Wif
    end

    def private_key : PrivateKey
    end

    def public_key : PublicKey
    end

    def address : String
    end

    def is_valid? : Bool
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

    private def to_wif(private_key : PrivateKey, network : Network) : Wif
    end

  end


  def to_hex(bytes) : String
  end

  def to_bytes(hex) : Array(UInt8)
  end

end
