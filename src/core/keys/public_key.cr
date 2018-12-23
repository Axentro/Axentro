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
  class PublicKey
    getter network : Core::Node::Network

    def initialize(public_key_hex : String, @network : Core::Node::Network = MAINNET)
      @hex = public_key_hex
      raise "invalid public key: #{@hex}" unless is_valid?
    end

    def self.from(hex : String, network : Core::Node::Network = MAINNET) : PublicKey
      PublicKey.new(hex, network)
    end

    def self.from(bytes : Bytes, network : Core::Node::Network = MAINNET) : PublicKey
      PublicKey.new(KeyUtils.to_hex(bytes), network)
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

    def address : Address
      Address.new(KeyUtils.get_address_from_public_key(self), @network)
    end

    def is_valid? : Bool
      @hex.hexbytes? != nil && @hex.size == 130
    end
  end
end
