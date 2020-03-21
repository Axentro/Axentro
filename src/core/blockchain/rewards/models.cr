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

module ::Sushi::Core::NonceModels
  struct MinerNonce
    JSON.mapping({
      value:     BlockNonce,
      timestamp: Int64,
      address:   String,
      node_id:   String,
    })

    getter value : BlockNonce
    getter timestamp : Int64 = 0_i64
    getter address : String = "0"
    getter node_id : String = "0"

    def initialize(@value : BlockNonce); end

    def self.from(block_nonce : BlockNonce) : MinerNonce
        MinerNonce.new(block_nonce)
    end

    def ==(other) : Bool
      value == other.value
    end

    def with_value(new_value : String) : MinerNonce
        value = new_value
        self
    end

    def with_timestamp(new_timestamp : Int64) : MinerNonce
      timestamp = new_timestamp
      self
    end

    def with_address(new_address : String) : MinerNonce
      address = new_address
      self
    end

    def with_node_id(new_node_id : String) : MinerNonce
      node_id = new_node_id
      self
    end
  end

  alias MinerNonces = Array(MinerNonce)
  alias BlockNonce = String
end
