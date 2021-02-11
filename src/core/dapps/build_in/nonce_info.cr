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

module ::Axentro::Core::DApps::BuildIn
  struct Nonce
    include JSON::Serializable
    property address : String
    property nonce : String
    property latest_hash : String
    property block_id : Int64
    property difficulty : Int32
    property timestamp : Int64

    def initialize(@address : String, @nonce : String, @latest_hash : String, @block_id : Int64, @difficulty : Int32, @timestamp : Int64); end
  end

  class NonceInfo < DApp
    def setup
    end

    def transaction_actions : Array(String)
      [] of String
    end

    def transaction_related?(action : String) : Bool
      false
    end

    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      ValidatedTransactions.passed(transactions)
    end

    def record(chain : Blockchain::Chain)
    end

    def clear
    end

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
      nil
    end

    def nonces(json, context, params) : Array(Nonce)
      address = json["address"].as_s
      block_id = json["block_id"].as_i64
      context.response.print api_success(nonces_impl(address, block_id))
      context
    end

    def pending_nonces(json, context, params) : Array(Nonce)
      address = json["address"].as_s
      context.response.print api_success(pending_nonces_impl(address))
      context
    end

    def nonces_impl(address : String, block_id : Int64) : Array(Nonce)
      database.find_nonces_by_address_and_block_id(address, block_id)
    end

    def pending_nonces_impl(address : String) : Array(Nonce)
      mining_block = blockchain.mining_block
      block_id = mining_block.index
      difficulty = mining_block.difficulty
      latest_hash = mining_block.to_hash
      MinerNoncePool.find_by_address(address).map do |mn|
        Nonce.new(address, mn.value, latest_hash, block_id, difficulty, mn.timestamp)
      end
    end

    def on_message(action : String, from_address : String, content : String, from = nil) : Bool
      false
    end
  end
end
