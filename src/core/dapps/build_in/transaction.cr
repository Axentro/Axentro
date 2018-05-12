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
      senders = SendersDecimal.from_json(json["senders"].to_json)
      recipients = RecipientsDecimal.from_json(json["recipients"].to_json)
      message = json["message"].as_s
      token = json["token"].as_s

      transaction = create_unsigned_transaction_impl(action, senders, recipients, message, token)

      context.response.print api_success(transaction)
      context
    end

    def create_unsigned_transaction_impl(
      action : String,
      senders : SendersDecimal,
      recipients : RecipientsDecimal,
      message : String,
      token : String,
      id : String = Transaction.create_id,
     )

      transaction = TransactionDecimal.new(
        id,
        action,
        senders,
        recipients,
        message,
        token,
        "0", # prev_hash
        "0", # sign_r
        "0", # sign_s
        false,
      ).to_transaction

      fee = transaction.total_fees

      # todo
      # check for specific fees
      raise "invalid fee #{fee} for the action #{action}" if fee <= 0

      transaction
    end

    def create_transaction(json, context, params)
      transaction = Transaction.from_json(json["transaction"].to_json)
      transaction = create_transaction_impl(transaction)

      context.response.print api_success(transaction)
      context
    end

    def create_transaction_impl(transaction : Transaction)
      node.broadcast_transaction(transaction)

      transaction
    end

    include TransactionModels
  end
end
