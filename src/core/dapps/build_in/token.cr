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
  class Token < DApp
    getter tokens : Array(String) = ["AXNT"]

    def setup
    end

    def transaction_actions : Array(String)
      ["create_token"]
    end

    def transaction_related?(action : String) : Bool
      action == "create_token"
    end

    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      vt = ValidatedTransactions.empty
      processed_transactions = transactions.select(&.is_coinbase?)

      transactions.reject(&.is_coinbase?).each do |transaction|
        raise "senders can only be 1 for token action" if transaction.senders.size != 1
        raise "number of specified senders must be 1 for 'create_token'" if transaction.senders.size != 1
        raise "number of specified recipients must be 1 for 'create_token'" if transaction.recipients.size != 1

        sender = transaction.senders[0]
        sender_address = sender[:address]
        sender_amount = sender[:amount]

        recipient = transaction.recipients[0]
        recipient_address = recipient[:address]
        recipient_amount = recipient[:amount]

        raise "address mismatch for 'create_token'. " +
              "sender: #{sender_address}, recipient: #{recipient_address}" if sender_address != recipient_address

        raise "amount mismatch for 'create_token'. " +
              "sender: #{sender_amount}, recipient: #{recipient_amount}" if sender_amount != recipient_amount

        token = transaction.token

        raise "invalid token name: #{token}" unless valid_token_name?(token)

        raise "the token #{token} is already created" if database.token_exists?(token)

        processed_transactions.each do |processed_transaction|
          raise "the token #{token} is already created" if processed_transaction.token == token
        end
        vt << transaction.as_validated
        processed_transactions << transaction
      rescue e : Exception
        vt << FailedTransaction.new(transaction, e.message || "unknown error", "token").as_validated
      end
      vt
    end

    # def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
    #   raise "senders can only be 1 for token action" if transaction.senders.size != 1
    #   raise "number of specified senders must be 1 for 'create_token'" if transaction.senders.size != 1
    #   raise "number of specified recipients must be 1 for 'create_token'" if transaction.recipients.size != 1

    #   sender = transaction.senders[0]
    #   sender_address = sender[:address]
    #   sender_amount = sender[:amount]

    #   recipient = transaction.recipients[0]
    #   recipient_address = recipient[:address]
    #   recipient_amount = recipient[:amount]

    #   raise "address mismatch for 'create_token'. " +
    #         "sender: #{sender_address}, recipient: #{recipient_address}" if sender_address != recipient_address

    #   raise "amount mismatch for 'create_token'. " +
    #         "sender: #{sender_amount}, recipient: #{recipient_amount}" if sender_amount != recipient_amount

    #   token = transaction.token

    #   raise "invalid token name: #{token}" unless valid_token_name?(token)

    #   raise "the token #{token} is already created" if database.token_exists?(token)

    #   prev_transactions.each do |prev_transaction|
    #     raise "the token #{token} is already created" if prev_transaction.token == token
    #   end

    #   true
    # end

    def self.valid_token_name?(token : String) : Bool
      unless token =~ /^[A-Z0-9]{1,20}$/
        token_rule = <<-RULE
You token '#{token}' is not valid

1. token name can only contain uppercase letters or numbers
2. token name length must be between 1 and 20 characters
RULE
        raise token_rule
      end

      true
    end

    def valid_token_name?(token : String) : Bool
      Token.valid_token_name?(token)
    end

    def record(chain : Blockchain::Chain)
    end

    def clear
    end

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
      case call
      when "token_list"
        return list(json, context, params)
      end

      nil
    end

    def list(json, context, params)
      page, per_page, direction = 0, 50, 0
      context.response.print api_success(tokens_list_impl(page, per_page, direction))
      context
    end

    def tokens_list_impl(page, per_page, direction)
      (["AXNT"] + database.get_paginated_tokens(page, per_page, Direction.new(direction).to_s)).to_set
    end

    def self.fee(action : String) : Int64
      scale_i64("10")
    end

    def on_message(action : String, from_address : String, content : String, from = nil)
      false
    end
  end
end
