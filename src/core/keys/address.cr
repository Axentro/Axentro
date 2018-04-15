# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

module ::Sushi::Core::Keys
  include Hashes

  class Address
    getter network : Core::Node::Network

    def initialize(hex_address : String, @network : Core::Node::Network = MAINNET, name : String = "generic")
      @hex = hex_address
      raise "invalid #{name} address checksum for: #{@hex}" unless is_valid?
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

    def self.get_network_from_address(hex_address) : Core::Node::Network
      decoded_address = Base64.decode_string(hex_address)

      case decoded_address[0..1]
      when MAINNET[:prefix]
        MAINNET
      when TESTNET[:prefix]
        TESTNET
      else
        raise "invalid network: #{decoded_address[0..1]} for address: #{hex_address}"
      end
    end

    def to_s : String
      as_hex
    end
  end
end
