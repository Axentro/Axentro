# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

module ::Axentro::Core::NonceModels
  struct MinerNonce
    include JSON::Serializable

    getter mid : String = "0"
    getter value : BlockNonce
    getter timestamp : Int64 = 0_i64
    getter address : String = "0"
    getter node_id : String = "0"
    getter difficulty : Int32 = 1

    def initialize(@value : BlockNonce); end

    def self.from(block_nonce : BlockNonce) : MinerNonce
      MinerNonce.new(block_nonce)
    end

    def ==(other) : Bool
      value == other.value
    end

    def with_mid(@mid : String) : MinerNonce
      self
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

    def with_difficulty(@difficulty : Int32) : MinerNonce
      self
    end
  end

  alias MinerNonces = Array(MinerNonce)
  alias BlockNonce = String
end
