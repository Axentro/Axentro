module ::Sushi::Core
  class UTXO < DApp
    @utxo_internal : Array(Hash(String, Int64)) = Array(Hash(String, Int64)).new

    def get(address : String) : Int64
      return 0_i64 if @utxo_internal.size < CONFIRMATION

      @utxo_internal.reverse[(CONFIRMATION - 1)..-1].each do |utxo_internal|
        return utxo_internal[address] if utxo_internal[address]?
      end

      0_i64
    end

    def get_unconfirmed(address : String, transactions : Array(Transaction)) : Int64
      utxos_transactions = 0_i64

      transactions.each do |transaction|
        utxos_transaction_senders = transaction.senders.select { |s| s[:address] == address }
        utxos_transaction_recipients = transaction.recipients.select { |r| r[:address] == address }
        utxos_transaction = utxos_transaction_recipients.reduce(0_i64) { |sum, utxo| sum + utxo[:amount] } -
                            utxos_transaction_senders.reduce(0_i64) { |sum, utxo| sum + utxo[:amount] + utxo[:fee] }

        utxos_transactions = utxos_transactions + utxos_transaction
      end

      unconfirmed_recorded = get_unconfirmed_recorded(address)

      utxos_transactions + unconfirmed_recorded
    end

    def get_unconfirmed_recorded(address : String) : Int64
      return 0_i64 if @utxo_internal.size == 0

      @utxo_internal.reverse.each do |utxo_internal|
        return utxo_internal[address] if utxo_internal[address]?
      end

      0_i64
    end

    def actions : Array(String)
      ["send"]
    end

    def valid_impl?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      raise "recipients have to be only one currently" if transaction.recipients.size != 1

      sender = transaction.senders[0]
      senders_amount = get_unconfirmed(sender[:address], prev_transactions)

      if senders_amount - sender[:amount] < 0_i64
        raise "sender has not enough coins: #{sender[:address]} (#{senders_amount})"
      end

      true
    end

    def calculate_for_transaction(transaction : Transaction) : Hash(String, Int64)
      utxo = Hash(String, Int64).new

      transaction.senders.each do |sender|
        utxo[sender[:address]] ||= 0_i64
        utxo[sender[:address]] = utxo[sender[:address]] - sender[:amount] - sender[:fee]
      end

      transaction.recipients.each do |recipient|
        utxo[recipient[:address]] ||= 0_i64
        utxo[recipient[:address]] = utxo[recipient[:address]] + recipient[:amount]
      end

      utxo
    end

    def calculate_for_block(block : Block) : Hash(String, Int64)
      utxo = Hash(String, Int64).new

      block.transactions.each_with_index do |transaction, i|
        utxo_transaction = calculate_for_transaction(transaction)
        utxo_transaction.each do |address, amount|
          utxo[address] ||= 0_i64
          utxo[address] = utxo[address] + amount
        end
      end

      utxo
    end

    def record(chain : Models::Chain)
      return if @utxo_internal.size >= chain.size

      chain[@utxo_internal.size..-1].each do |block|
        @utxo_internal.push(Hash(String, Int64).new)

        utxo_block = calculate_for_block(block)
        utxo_block.each do |address, amount|
          @utxo_internal[-1][address] ||= get_unconfirmed_recorded(address)
          @utxo_internal[-1][address] = @utxo_internal[-1][address] + amount
        end
      end
    end

    def clear
      @utxo_internal.clear
    end

    def fee(action : String) : Int64
      1_i64
    end

    include Logger
    include Consensus
    include Common::Color
  end
end
