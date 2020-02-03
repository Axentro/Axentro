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

module ::Sushi::Core::DApps::BuildIn
  struct Reject
    getter transaction_id
    getter reason

    def initialize(@transaction_id : String, @reason : String); end

    def to_json(b)
      {transaction_id => reason}.to_json
    end
  end

  class Rejects < DApp
    def setup
    end

    def transaction_actions : Array(String)
      [] of String
    end

    def transaction_related?(action : String) : Bool
      false
    end

    def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      true
    end

    def record_reject(transaction_id : String, e : Exception)
      error_message = e.message ? e.message.not_nil! : "unknown"
      record_reject(transaction_id, error_message)
    end

    def record_reject(transaction_id : String, error_message : String)
      database.insert_reject(Reject.new(transaction_id, error_message))
    end

    def record(chain : Blockchain::Chain)
    end

    def clear
    end

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
    end

    def find(transaction_id : String) : Reject?
      database.find_reject(transaction_id)
    end

    def on_message(action : String, from_address : String, content : String, from = nil)
      false
    end
  end
end
