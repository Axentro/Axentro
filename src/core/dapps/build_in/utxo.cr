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
  class UTXO < DApp
    DEFAULT = "SUSHI"

    @utxo_internal : Array(Hash(String, Hash(String, Int64))) = Array(Hash(String, Hash(String, Int64))).new

    def setup
    end

    def get_for(address : String, utxo : Array(Hash(String, Hash(String, Int64))), token : String) : Int64
      utxo.each do |u|
        return u[token][address] if u[token]? && u[token][address]?
      end

      0_i64
    end

    def get(address : String, token : String, confirmation : Int32) : Int64
      return 0_i64 if @utxo_internal.size < confirmation

      get_for(address, @utxo_internal.reverse[(confirmation - 1)..-1], token)
    end

    def get_pending(address : String, transactions : Array(Transaction), token : String) : Int64
      utxo_transactions = calculate_for_transactions(transactions)

      utxo_pending = get_for(address, @utxo_internal.reverse, token)
      utxo_pending += utxo_transactions[token][address] if utxo_transactions[token]? && utxo_transactions[token][address]?
      utxo_pending
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

      if amount_token + amount_token_as_recipients - pay_token < 0
        raise "sender has not enough token(#{transaction.token}). " +
              "sender has #{scale_decimal(amount_token)} + #{scale_decimal(amount_token_as_recipients)} but try to pay #{scale_decimal(pay_token)}"
      end

      if amount_default + amount_default_as_recipients - pay_default < 0
        raise "sender has not enough token(#{DEFAULT}). " +
              "sender has #{scale_decimal(amount_default)} + #{scale_decimal(amount_default_as_recipients)} but try to pay #{scale_decimal(pay_default)}"
      end

      true
    end

    def calculate_for_transaction(transaction : Transaction) : Hash(String, Hash(String, Int64))
      utxo = Hash(String, Hash(String, Int64)).new
      utxo[transaction.token] = Hash(String, Int64).new
      utxo[DEFAULT] ||= Hash(String, Int64).new

      transaction.senders.each do |sender|
        utxo[transaction.token][sender[:address]] ||= 0_i64
        utxo[transaction.token][sender[:address]] -= sender[:amount]
        utxo[DEFAULT][sender[:address]] ||= 0_i64
        utxo[DEFAULT][sender[:address]] -= sender[:fee]
      end

      transaction.recipients.each do |recipient|
        utxo[transaction.token][recipient[:address]] ||= 0_i64
        utxo[transaction.token][recipient[:address]] += recipient[:amount]
      end

      utxo
    end

    def calculate_for_transactions(transactions : Array(Transaction)) : Hash(String, Hash(String, Int64))
      utxo = Hash(String, Hash(String, Int64)).new

      transactions.each_with_index do |transaction, _|
        utxo_transaction = calculate_for_transaction(transaction)
        utxo_transaction.each do |token, address_amount|
          utxo[token] ||= Hash(String, Int64).new

          address_amount.each do |address, amount|
            utxo[token][address] ||= 0_i64
            utxo[token][address] += amount
          end
        end
      end

      utxo
    end

    def create_token(address : String, amount : Int64, token : String)
      @utxo_internal[-1][token] ||= Hash(String, Int64).new
      @utxo_internal[-1][token][address] = amount
    end

    def record(chain : Blockchain::Chain)
      return if @utxo_internal.size >= chain.size

      chain[@utxo_internal.size..-1].each do |block|
        @utxo_internal.push(Hash(String, Hash(String, Int64)).new)

        utxo_block = calculate_for_transactions(block.transactions)
        utxo_block.each do |token, utxo|
          utxo.each do |address, amount|
            @utxo_internal[-1][token] ||= Hash(String, Int64).new
            @utxo_internal[-1][token][address] ||= get_pending(address, [] of Transaction, token)
            @utxo_internal[-1][token][address] = @utxo_internal[-1][token][address] + amount
          end
        end
      end
    end

    def clear
      @utxo_internal.clear
    end

    def define_rpc?(call, json, context, params)
      case call
      when "amount"
        return amount(json, context, params)
      end

      nil
    end

    def amount(json, context, params)
      address = json["address"].as_s
      token = json["token"].as_s
      confirmation = json["confirmation"].as_i

      context.response.print api_success(amount_impl(address, token, confirmation))
      context
    end

    def amount_impl(address, token, confirmation : Int32)
      pairs = [] of NamedTuple(token: String, amount: String)

      tokens = blockchain.token.tokens
      tokens.each do |_token|
        next if _token != token && token != "all"

        amount = get(address, _token, confirmation)
        pairs << {token: _token, amount: scale_decimal(amount)}
      end

      {confirmation: confirmation, pairs: pairs}
    end

    def self.fee(action : String) : Int64
      scale_i64("0.0001")
    end

    def on_message(action : String, from_address : String, content : String, from = nil)
      return false unless action == "amount"

      _m_content = M_CONTENT_CLIENT_AMOUNT.from_json(content)

      token = _m_content.token
      confirmation = _m_content.confirmation

      node.send_content_to_client(
        from_address,
        from_address,
        amount_impl(from_address, token, confirmation).to_json,
        from,
      )
    end

    include Consensus
  end
end
