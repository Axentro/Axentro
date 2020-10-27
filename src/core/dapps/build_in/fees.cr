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
  class Fees < DApp
    def setup
    end

    def transaction_actions : Array(String)
      [] of String
    end

    def transaction_related?(action : String) : Bool
      false
    end

    # def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
    #   true
    # end

    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      ValidatedTransactions.empty
    end

    def record(chain : Blockchain::Chain)
    end

    def clear
    end

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
      case call
      when "fees"
        return fees(json, context, params)
      end

      nil
    end

    def fees(json, context, params)
      context.response.print api_success(fees_impl)
      context
    end

    def fees_impl
      fees = Hash(String, String).new

      blockchain.dapps.each do |dapp|
        dapp.transaction_actions.each do |action|
          fees[action] = scale_decimal(dapp.class.fee(action)) if dapp.class.fee(action) > 0
        end
      end

      fees
    end

    def on_message(action : String, from_address : String, content : String, from = nil)
      return false unless action == "fee"

      node.send_content_to_client(from_address, from_address, fees_impl.to_json, from)
    end
  end
end
