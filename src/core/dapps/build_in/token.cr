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
  struct TokenInfo
    getter created_by : String
    getter is_locked : Bool

    def initialize(@created_by : String, @is_locked : Bool)
    end
  end

  class Token < DApp
    getter tokens : Array(String) = ["AXNT"]

    def setup
    end

    def transaction_actions : Array(String)
      ["create_token", "update_token", "lock_token", "burn_token"]
    end

    def transaction_related?(action : String) : Bool
      transaction_actions.includes?(action)
    end

    # split these out to reduce complexity in the future
    # ameba:disable Metrics/CyclomaticComplexity
    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      vt = ValidatedTransactions.empty
      processed_transactions = transactions.select(&.is_coinbase?)

      body_transactions = transactions.reject(&.is_coinbase?)
      token_map = database.token_info(body_transactions.map(&.token).reject(&.==(TOKEN_DEFAULT)).uniq!)

      body_transactions.each do |transaction|
        token = transaction.token
        action = transaction.action

        # common rules for token
        raise "must not be the default token: #{token}" if token == TOKEN_DEFAULT
        raise "senders can only be 1 for token action" if transaction.senders.size != 1
        raise "number of specified senders must be 1 for '#{action}'" if transaction.senders.size != 1
        raise "number of specified recipients must be 1 for '#{action}'" if transaction.recipients.size != 1

        sender = transaction.senders[0]
        sender_address = sender.address
        sender_amount = sender.amount

        recipient = transaction.recipients[0]
        recipient_address = recipient.address
        recipient_amount = recipient.amount

        raise "address mismatch for '#{action}'. " +
              "sender: #{sender_address}, recipient: #{recipient_address}" if sender_address != recipient_address

        raise "amount mismatch for '#{action}'. " +
              "sender: #{sender_amount}, recipient: #{recipient_amount}" if sender_amount != recipient_amount

        raise "invalid token name: #{token}" unless valid_token_name?(token)

        if ["create_token", "update_token", "burn_token"].includes?(action)
          raise "invalid quantity: #{recipient_amount}, must be a positive number greater than 0" unless recipient_amount > 0_i64
        end

        # rules for create token
        token_exists_in_db = !token_map[token]?.nil?

        # find if the token was created within the current set of transactions
        token_exists_in_transactions = processed_transactions.find { |processed_transaction|
          processed_transaction.token == token && processed_transaction.action == "create_token"
        }

        # find if the token was locked within the current set of transactions
        token_locked_in_transactions = processed_transactions.find { |processed_transaction|
          processed_transaction.token == token && processed_transaction.action == "lock_token"
        }

        if action == "create_token"
          raise "the token #{token} is already created" if token_exists_in_db

          processed_transactions.each do |processed_transaction|
            raise "the token #{token} is already created" if processed_transaction.token == token
          end
        end

        # rules for just update
        if action == "update_token"
          if (token_exists_in_db && token_map[token].is_locked) || !token_locked_in_transactions.nil?
            raise "the token: #{token} is locked and may no longer be updated"
          end
        end

        # rules for just burn
        if action == "burn_token"
          action_name = action.split("_").join(" ")
          # token must already exist either in the db or in current transactions
          raise "the token #{token} does not exist, you must create it before attempting to perform #{action_name}" unless (token_exists_in_db || token_exists_in_transactions)
        end

        # rules for update and lock token
        if ["update_token", "lock_token"].includes?(action)
          action_name = action.split("_").join(" ")

          # token must already exist either in the db or in current transactions
          raise "the token #{token} does not exist, you must create it before attempting to perform #{action_name}" unless (token_exists_in_db || token_exists_in_transactions)

          unless token_exists_in_transactions.nil?
            token_creator = token_exists_in_transactions.not_nil!.recipients[0].address
            raise "only the token creator can perform #{action_name} on existing token: #{token}" unless token_creator == recipient_address
          end

          if token_exists_in_db
            raise "only the token creator can perform #{action_name} on existing token: #{token}" unless token_map[token].created_by == recipient_address
          end
        end

        # rules for just lock token
        if action == "lock_token"
          raise "the sender amount must be 0 when locking the token: #{token}" unless recipient_amount == 0_i64

          if (token_exists_in_db && token_map[token].is_locked) || !token_locked_in_transactions.nil?
            raise "the token: #{token} is already locked"
          end
        end

        vt << transaction
        processed_transactions << transaction
      rescue e : Exception
        vt << FailedTransaction.new(transaction, e.message || "unknown error")
      end
      vt
    end

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
      case action
      when "create_token"
        return scale_i64("10")
      when "update_token"
        return scale_i64("0.0001")
      when "lock_token"
        return scale_i64("0.0001")
      when "burn_token"
        return scale_i64("0.0001")
      end

      raise "got unknown action #{action} while getting a fee for token"
    end

    def on_message(action : String, from_address : String, content : String, from = nil) : Bool
      false
    end
  end
end
