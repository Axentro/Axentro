module ::Sushi::Core::Keys
  include Hashes
  include Sushi::Core::Models

  class Address
    getter network : Network

    def initialize(hex_address : String, @network : Network = MAINNET)
      @hex = hex_address
      raise "Invalid address checksum for: #{@hex}" unless is_valid?
    end

    def as_hex : String
      @hex
    end

    def is_valid?
      decoded_address = Base64.decode_string(@hex)
      return false unless decoded_address.size == 48
      version_address = decoded_address[0..-7]
      hashed_address = sha256(sha256(version_address))
      checksum = decoded_address[-6..-1]
      checksum == hashed_address[0..5]
    end
  end
end
