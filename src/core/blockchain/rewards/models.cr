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
      id:        String,
      value:     BlockNonce,
      timestamp: Int64,
      address:   String,
      node_id:   String,
    })

    getter id : String
    getter value : BlockNonce
    getter timestamp : Int64 = 0_i64
    getter address : String = "0"
    getter node_id : String = "0"

    def initialize(@value : BlockNonce, @id : String = MinerNonce.create_id); end

    def self.from(block_nonce : BlockNonce) : MinerNonce
      MinerNonce.new(block_nonce)
    end

    def self.create_id : String
      tmp_id = Random::Secure.hex(32)
      return create_id if tmp_id[0] == "0"
      tmp_id
    end

    def ==(other) : Bool
      value == other.value
    end

    def with_value(@value : String) : MinerNonce
      self
    end

    def with_timestamp(@timestamp : Int64) : MinerNonce
      self
    end

    def with_address(@address : String) : MinerNonce
      self
    end

    def with_node_id(@node_id : String) : MinerNonce
      self
    end
  end

  alias MinerNonces = Array(MinerNonce)
  alias BlockNonce = String
end
