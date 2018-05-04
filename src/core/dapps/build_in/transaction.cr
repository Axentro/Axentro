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
  class TransactionCreator < DApp
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

    def record(chain : Blockchain::Chain)
    end

    def clear
    end

    def define_rpc?(call, json, context, params)
      case call
      when "create_unsigned_transaction"
        return create_unsigned_transaction(json, context, params)
      when "create_transaction"
        return create_transaction(json, context, params)
      end

      nil
    end

    def create_unsigned_transaction(json, context, params)
      action = json["action"].as_s
      senders = Core::Transaction::Senders.from_json(json["senders"].to_json)
      recipients = Core::Transaction::Recipients.from_json(json["recipients"].to_json)
      message = json["message"].as_s
      token = json["token"].as_s

      transaction = blockchain.create_unsigned_transaction(
        action,
        senders,
        recipients,
        message,
        token,
      )

      fee = transaction.calculate_fee

      raise "invalid fee #{fee} for the action #{action}" if fee <= 0.0

      context.response.print api_success(transaction)
      context
    end

    def create_transaction(json, context, params)
      transaction = Transaction.from_json(json["transaction"].to_json)

      node.broadcast_transaction(transaction)

      context.response.print api_success(transaction)
      context
    end
  end
end
