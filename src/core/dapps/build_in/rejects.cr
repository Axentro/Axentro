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
  class Rejects < DApp
    @rejects : Hash(String, String) = Hash(String, String).new

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

    # TODO - this should be recorded in the db
    def record_reject(transaction_id : String, error_message : String)
      @rejects[transaction_id] ||= error_message
    end

    # TODO - Store rejects in the db and only keep latest 10,000
    # record should load the 10k into mem and trim the db
    def record(chain : Blockchain::Chain)
    end

    def clear
      @rejects.clear
    end

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
    end

    def find(transaction_id : String) : String?
      if rejected_reason = @rejects[transaction_id]?
        return rejected_reason
      end

      nil
    end

    def on_message(action : String, from_address : String, content : String, from = nil)
      false
    end
  end
end
