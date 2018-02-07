module ::Sushi::Core::Keys
  extend Hashes

  class PublicKey

    def initialize(hex : String)
      @hex = hex
    end

    def self.from(hex : String) : PublicKey
      PublicKey.new(hex)
    end

    def self.from(bytes : Bytes) : PublicKey
      PublicKey.new(to_hex(bytes))
    end

    def as_hex : String
      @hex
    end

    def as_bytes : Bytes
      to_bytes(@hex)
    end

    def address : String
      secp256k1 = ECDSA::Secp256k1.new
      p secp256k1.create_key_pair(self.as_bytes)
      ""
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

    def self.from(bytes : Bytes) : PrivateKey
        PrivateKey.new(to_hex(bytes))
    end

    def as_hex : String
      @hex
    end

    def as_bytes : Bytes
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


  def to_hex(bytes : Bytes) : String
    bytes.to_unsafe.to_slice(bytes.size).hexstring
  end

  def to_bytes(hex : String) : Bytes
    hex.hexbytes
  end

end
