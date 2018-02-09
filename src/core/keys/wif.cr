module ::Sushi::Core::Keys
  include Hashes
  include Sushi::Core::Models

  class Wif
    def initialize(wif_hex : String)
      @hex = wif_hex
      raise "Invalid wif: #{@hex}" unless is_valid?
    end

    def as_hex
      @hex
    end

    def self.from(private_key : PrivateKey, network : Network = {prefix: "M0", name: "mainnet"}) : Wif
      KeyUtils.to_wif(private_key, network)
    end

    def private_key : PrivateKey
      KeyUtils.from_wif(self)[:private_key]
    end

    def public_key : PublicKey
      KeyUtils.from_wif(self)[:private_key].public_key
    end

    def network : Network
      KeyUtils.from_wif(self)[:network]
    end

    def address : Address
      res = KeyUtils.from_wif(self)
      public_key = res[:private_key].public_key
      network = res[:network]
      Address.new(KeyUtils.get_address_from_public_key(public_key), network)
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
end
