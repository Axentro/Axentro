module ::Sushi::Core::DApps::BuildIn
  class UTXO < DApp
    DEFAULT = "SHARI"

    # todo: sample for 'If you send me xxx TOKEN, I'll return you yyy TOKEN'
    @utxo_internal : Array(Hash(String, Hash(String, Int64))) = Array(Hash(String, Hash(String, Int64))).new

    def get_for(address : String, utxo : Array(Hash(String, Hash(String, Int64))), token : String) : Int64
      utxo.each do |u|
        return u[token][address] if u[token]? && u[token][address]?
      end

      0_i64
    end

    def get(address : String, token : String) : Int64
      return 0_i64 if @utxo_internal.size < CONFIRMATION

      get_for(address, @utxo_internal.reverse[(CONFIRMATION - 1)..-1], token)
    end

    def get_unconfirmed(address : String, transactions : Array(Transaction), token : String) : Int64
      utxo_transactions = calculate_for_transactions(transactions)

      utxo_unconfirmed = get_for(address, @utxo_internal.reverse, token)
      utxo_unconfirmed += utxo_transactions[token][address] if utxo_transactions[token]? && utxo_transactions[token][address]?
      utxo_unconfirmed
    end

    def actions : Array(String)
      ["send"]
    end

    def related?(action : String) : Bool
      true
    end

    def valid_impl?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      raise "recipients have to be less than one" if transaction.recipients.size > 1

      sender = transaction.senders[0]

      amount_token = get_unconfirmed(sender[:address], prev_transactions, transaction.token)
      amount_default = transaction.token == DEFAULT ? amount_token : get_unconfirmed(sender[:address], prev_transactions, DEFAULT)

      as_recipients = transaction.recipients.select { |recipient| recipient[:address] == sender[:address] }
      amount_token_as_recipients = as_recipients.reduce(0_i64) { |sum, recipient| sum + recipient[:amount] }
      amount_default_as_recipients = transaction.token == DEFAULT ? amount_token_as_recipients : 0

      pay_token = sender[:amount]
      pay_default = (transaction.token == DEFAULT ? sender[:amount] : 0_i64) + sender[:fee]

      if amount_token + amount_token_as_recipients - pay_token < 0
        raise "sender has not enough token(#{transaction.token}). sender has #{amount_token} + #{amount_token_as_recipients} but try to pay #{pay_token}"
      end

      if amount_default + amount_default_as_recipients - pay_default < 0
        raise "sender has not enough token(#{DEFAULT}). sender has #{amount_default} + #{amount_default_as_recipients} but try to pay #{pay_default}"
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

      puts "----- calculate_for_transaction"
      p utxo

      utxo
    end

    def calculate_for_transactions(transactions : Array(Transaction)) : Hash(String, Hash(String, Int64))
      utxo = Hash(String, Hash(String, Int64)).new

      transactions.each_with_index do |transaction, i|
        utxo_transaction = calculate_for_transaction(transaction)
        utxo_transaction.each do |token, address_amount|
          utxo[token] ||= Hash(String, Int64).new

          address_amount.each do |address, amount|
            utxo[token][address] ||= 0_i64
            utxo[token][address] += amount
          end
        end
      end

      puts "----- calculate_for_transactions (block)"
      p utxo

      utxo
    end

    def record(chain : Models::Chain)
      return if @utxo_internal.size >= chain.size

      chain[@utxo_internal.size..-1].each do |block|
        @utxo_internal.push(Hash(String, Hash(String, Int64)).new)

        utxo_block = calculate_for_transactions(block.transactions)
        utxo_block.each do |token, utxo|
          utxo.each do |address, amount|
            @utxo_internal[-1][token] ||= Hash(String, Int64).new
            @utxo_internal[-1][token][address] ||= get_unconfirmed(address, [] of Transaction, token)
            @utxo_internal[-1][token][address] = @utxo_internal[-1][token][address] + amount
          end
        end
      end
    end

    def clear
      @utxo_internal.clear
    end

    def rpc?(call, json, context, params)
      case call
      when "amount"
        return amount(json, context, params)
      end

      nil
    end

    def amount(json, context, params)
      address = json["address"].to_s
      unconfirmed = json["unconfirmed"].as_bool

      amount = unconfirmed ? get_unconfirmed(address, Array(Transaction).new, DEFAULT) : get(address, DEFAULT)

      json = {amount: amount, address: address, unconfirmed: unconfirmed}.to_json

      context.response.print json
      context
    end

    def self.fee(action : String) : Int64
      1_i64
    end

    include Consensus
  end
end
