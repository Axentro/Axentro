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
  struct TokenQuantity
    getter name : String
    getter quantities : Array(AddressQuantity)

    def initialize(@name : String, @quantities : Array(AddressQuantity))
    end

    def ==(other)
      name == other.name && quantities == other.quantities
    end

    def self.find_amount(tokens : Array(TokenQuantity), token : String, address : String)
      tokens.select { |tq| tq.name == token }.flat_map do |tq|
        tq.quantities.select { |aq| aq.address == address }.reduce(0) { |acc, aq| acc + aq.quantity }
      end.sum.to_i64
    end

    def self.find_last_amount(utxo : Array(TokenQuantity), token : String, address : String)
      utxo.each do |tq|
        if tq.name == token && !tq.quantities.empty?
          result = tq.quantities.find{|aq| aq.address == address}
          if !result.nil?
            return result.quantity
          end
        end
      end
      0_i64
    end
  end

  struct AddressQuantity
    getter address : String
    property quantity : Int64

    def initialize(@address : String, @quantity : Int64)
    end

    def ==(other)
      address == other.address && quantity == other.quantity
    end
  end

  struct GroupBy
    getter label : String
    getter items : Array(TokenAddressQuantity)

    def initialize(@label : String, @items : Array(TokenAddressQuantity))
    end
  end

  struct TokenAddressQuantity
    getter token : String
    getter address : String
    property amount : Int64

    def initialize(@token : String, @address : String, @amount : Int64 = 0_i64)
    end

    def ==(other)
      self.token == other.token && self.address == other.address
    end

    def self.find(items : Array(TokenAddressQuantity), token : String, address : String)
      items.find { |taq| taq.token == token && taq.address = address }
    end

    def self.decrement_sender(items : Array(TokenAddressQuantity), token : String, address : String, amount : Int64, fee : Int64) : Array(TokenAddressQuantity)
      items.map do |taq|
        if taq.token == token && taq.address == address
          taq.amount -= amount
        end

        if taq.token == TOKEN_DEFAULT && taq.address == address
          taq.amount -= fee
        end
        taq
      end
    end

    def self.increment_recipient(items : Array(TokenAddressQuantity), token : String, address : String, amount : Int64) : Array(TokenAddressQuantity)
      items.map do |taq|
        if taq.token == token && taq.address == address
          taq.amount += amount
          taq
        else
          taq
        end
      end
    end
  end

  class UTXO < DApp
    DEFAULT = "SUSHI"

    @utxo_internal : Array(TokenQuantity) = [] of TokenQuantity

    def setup
    end

    def get_for(address : String, utxo : Array(TokenQuantity), token : String) : Int64
      TokenQuantity.find_last_amount(utxo, token, address)
    end

    def get(address : String, token : String, confirmation : Int32) : Int64
      return 0_i64 if @utxo_internal.size < confirmation

      get_for(address, @utxo_internal.reverse[(confirmation - 1)..-1], token)
    end

    def get_pending(address : String, transactions : Array(Transaction), token : String) : Int64
      utxo_transactions = calculate_for_transactions(transactions)

      utxo_pending = get_for(address, @utxo_internal.reverse, token)
      utxo_pending += TokenQuantity.find_amount(utxo_transactions, token, address)
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

      # TODO: Fix the error wording here. Needs discussion.
      if amount_token + amount_token_as_recipients - pay_token < 0
        raise "Unable to send #{scale_decimal(pay_token)} to recipient because you do not have enough. Current tokens: #{scale_decimal(amount_token)} + #{scale_decimal(amount_token_as_recipients)}"
      end

      if amount_default + amount_default_as_recipients - pay_default < 0
        raise "Unable to send #{scale_decimal(pay_default)} to recipient because you do not have enough. Current tokens: #{scale_decimal(amount_default)} + #{scale_decimal(amount_default_as_recipients)}"
      end

      true
    end

    def calculate_for_transactions(transactions : Array(Transaction)) : Array(TokenQuantity)
      unique_tokens = transactions.map { |txn| txn.token }.uniq
      unique_addresses = transactions.flat_map { |txn| txn.senders.map { |s| s[:address] } + txn.recipients.map { |r| r[:address] } }.uniq
      token_addresses = unique_addresses.flat_map { |address| unique_tokens.flat_map { |token| TokenAddressQuantity.new(token, address) } }

      transactions.each do |transaction|
        transaction.senders.each do |sender|
          token_addresses = TokenAddressQuantity.decrement_sender(token_addresses, transaction.token, sender[:address], sender[:amount], sender[:fee])
        end
        transaction.recipients.each do |recipient|
          token_addresses = TokenAddressQuantity.increment_recipient(token_addresses, transaction.token, recipient[:address], recipient[:amount])
        end
      end

      unique_tokens.map do |token|
        GroupBy.new(token, token_addresses.select { |taq| taq.token == token })
      end.map do |group|
        TokenQuantity.new(group.label, group.items.map { |taq| AddressQuantity.new(taq.address, taq.amount) })
      end
    end

    def create_token(address : String, amount : Int64, token : String)
      @utxo_internal << TokenQuantity.new(token, [AddressQuantity.new(address, amount)])
    end

    def record(chain : Blockchain::Chain)
      return if @utxo_internal.size >= chain.size

      chain[@utxo_internal.size..-1].each do |block|
        @utxo_internal << TokenQuantity.new(DEFAULT, [] of AddressQuantity) if block.transactions.empty?

        calculate_for_transactions(block.transactions).each do |tq|
          updated_quantities = tq.quantities.map do |aq|
            aq.quantity += TokenQuantity.find_last_amount(@utxo_internal.reverse, tq.name, aq.address)
            aq
          end
          @utxo_internal << TokenQuantity.new(tq.name, updated_quantities)
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

      _m_content = MContentClientAmount.from_json(content)

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
