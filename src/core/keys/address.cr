module ::Sushi::Core::Keys
  include Hashes
  include Sushi::Core::Models

  class Address

    getter network : Network

    def initialize(hex_address : String, @network : Network = MAINNET, name : String = "generic")
      @hex = hex_address
      raise "Invalid #{name} address checksum for: #{@hex}" unless is_valid?
    end

    def as_hex : String
      @hex
    end

    def self.from(hex_address : String, name : String = "") : Address
      network = get_network_from_address(hex_address)
      Address.new(hex_address, network, name)
    end

    def is_valid?
      decoded_address = Base64.decode_string(@hex)
      return false unless decoded_address.size == 48
      version_address = decoded_address[0..-7]
      hashed_address = sha256(sha256(version_address))
      checksum = decoded_address[-6..-1]
      checksum == hashed_address[0..5]
    end

    def self.get_network_from_address(hex_address) : Network
      decoded_address = Base64.decode_string(hex_address)

      case decoded_address[0..1]
      when MAINNET[:prefix]
        MAINNET
      when TESTNET[:prefix]
        TESTNET
      else
        raise "Invalid network: #{decoded_address[0..1]} for address: #{hex_address}"
      end
    end

    def to_s : String
      as_hex
    end
  end
end
