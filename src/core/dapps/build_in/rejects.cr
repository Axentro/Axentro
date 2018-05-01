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
      @rejects[transaction_id] ||= error_message
    end

    def record(chain : Blockchain::Chain)
    end

    def clear
      @rejects.clear
    end

    def define_rpc?(call, json, context, params)
      case call
      when "rejects"
        return rejects?(json, context, params)
      end

      nil
    end

    def rejects?(json, context, params)
      transaction_id = json["transaction_id"].as_s

      result = if rejected_reason = @rejects[transaction_id]?
                 {
                   rejected: true,
                   reason:   rejected_reason,
                 }
               else
                 {
                   rejected: false,
                   reason:   "",
                 }
               end

      context.response.print api_success(result)
      context
    end
  end
end
