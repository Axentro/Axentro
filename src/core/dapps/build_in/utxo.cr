# Copyright © 2017-2018 The Axentro Core developers
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
  struct TokenQuantity
    getter token : String
    getter amount : Int64

    def initialize(@token : String, @amount : Int64); end
  end

  class UTXO < DApp
    DEFAULT = "AXNT"

    def setup
    end

    def get_for(address : String, token : String) : Int64
      database.get_address_amount(address).select { |r| r.token == token }.map(&.amount).sum
    end

    def get_pending(address : String, transactions : Array(Transaction), token : String) : Int64
      historic = get_for(address, token)

      if token == "AXNT"
        fees_sum = transactions.flat_map(&.senders).select { |s| s[:address] == address }.map(&.[:fee]).sum
        senders_sum = transactions.select { |t| t.token == token }.flat_map(&.senders).select { |s| s[:address] == address }.map(&.[:amount]).sum
        recipients_sum = transactions.select { |t| t.token == token }.flat_map(&.recipients).select { |r| r[:address] == address }.map(&.[:amount]).sum
        historic + (recipients_sum - (senders_sum + fees_sum))
      else
        senders_sum = transactions.select { |t| t.token == token }.flat_map(&.senders).select { |s| s[:address] == address }.map(&.[:amount]).sum
        recipients_sum = transactions.select { |t| t.token == token }.flat_map(&.recipients).select { |r| r[:address] == address }.map(&.[:amount]).sum
        historic + (recipients_sum - (senders_sum))
      end
    end

    def transaction_actions : Array(String)
      ["send"]
    end

    def transaction_related?(action : String) : Bool
      true
    end

    def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      raise "there must be 1 or less recipients" if transaction.recipients.size > 1
      raise "there must be 1 sender" if transaction.senders.size != 1

      sender = transaction.senders[0]

      amount_token = get_pending(sender[:address], prev_transactions, transaction.token)
      amount_default = transaction.token == DEFAULT ? amount_token : get_pending(sender[:address], prev_transactions, DEFAULT)

      as_recipients = transaction.recipients.select { |recipient| recipient[:address] == sender[:address] }
      amount_token_as_recipients = as_recipients.reduce(0_i64) { |sum, recipient| sum + recipient[:amount] }
      amount_default_as_recipients = transaction.token == DEFAULT ? amount_token_as_recipients : 0_i64

      pay_token = sender[:amount]
      pay_default = (transaction.token == DEFAULT ? sender[:amount] : 0_i64) + sender[:fee]

      total_available = amount_token + amount_token_as_recipients
      if (total_available - pay_token) < 0
        raise "Unable to send #{scale_decimal(pay_token)} #{transaction.token} to recipient because you do not have enough #{transaction.token}. You currently have: #{scale_decimal(amount_token)} #{transaction.token} and you are receiving: #{scale_decimal(amount_token_as_recipients)} #{transaction.token} from senders,  giving a total of: #{scale_decimal(total_available)} #{transaction.token}"
      end

      total_default_available = amount_default + amount_default_as_recipients
      if (total_default_available - pay_default) < 0
        raise "Unable to send #{scale_decimal(pay_default)} #{DEFAULT} to recipient because you do not have enough #{DEFAULT}. You currently have: #{scale_decimal(amount_default)} #{DEFAULT} and you are receiving: #{scale_decimal(amount_default_as_recipients)} #{DEFAULT} from senders,  giving a total of: #{scale_decimal(total_default_available)} #{DEFAULT}"
      end

      true
    end

    def record(chain : Blockchain::Chain)
    end

    def clear
    end

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
      case call
      when "amount"
        return amount(json, context, params)
      end

      nil
    end

    def amount(json, context, params)
      address = json["address"].as_s
      token = json["token"].as_s

      context.response.print api_success(amount_impl(address, token))
      context
    end

    def amount_impl(address, token)
      pairs = [] of NamedTuple(token: String, amount: String)

      if token != "all"
        tokens = database.get_address_amount(address).select { |r| r.token == token }
        if tokens.empty?
          pairs
        else
          balance = tokens.map(&.amount).sum
          pairs << {token: token, amount: scale_decimal(balance)}
        end
      else
        database.get_address_amount(address).each do |tq|
          pairs << {token: tq.token, amount: scale_decimal(tq.amount)}
        end
      end
      confirmation = database.get_amount_confirmation(address)
      {confirmation: confirmation, pairs: pairs}
    end

    def self.fee(action : String) : Int64
      scale_i64("0.0001")
    end

    def on_message(action : String, from_address : String, content : String, from = nil)
      return false unless action == "amount"

      _m_content = MContentClientAmount.from_json(content)

      token = _m_content.token

      node.send_content_to_client(
        from_address,
        from_address,
        amount_impl(from_address, token).to_json,
        from,
      )
    end

    include Consensus
  end
end
