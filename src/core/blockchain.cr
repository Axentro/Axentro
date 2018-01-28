require "./blockchain/consensus"
require "./blockchain/*"

module ::Sushi::Core
  class Blockchain
    getter chain : Models::Chain = Models::Chain.new
    getter transaction_pool = [] of Transaction
    getter wallet : Wallet
    getter utxo : UTXO

    @coinbase_transaction : Transaction?

    def initialize(@wallet : Wallet, @database : Database? = nil)
      @utxo = UTXO.new

      if database = @database
        restore_from_database(database)
      else
        set_genesis
      end

      @coinbase_transaction = create_coinbase_transaction([] of Models::Miner)
    end

    def coinbase_transaction : Transaction
      @coinbase_transaction.not_nil!
    end

    def set_genesis
      @chain.push(genesis_block)

      if database = @database
        database.push_block(genesis_block)
      end
    end

    def restore_from_database(database : Database)
      current_index = 0_i64

      loop do
        _block = database.get_block(current_index)

        break unless block = _block
        break unless block.valid_as_latest?(self)

        @chain.push(block)

        current_index += 1
      end
    rescue e : Exception
      database.delete_blocks(current_index.not_nil!)
    ensure
      set_genesis if @chain.size == 0
    end

    def update_coinbase_transaction(miners : Models::Miners)
      @coinbase_transaction = create_coinbase_transaction(miners)
      @transaction_pool.clear
    end

    def push_block?(nonce : UInt64, miners : Models::Miners) : Block?
      return nil unless latest_block.valid_nonce?(nonce)

      index = @chain.size.to_i64

      transactions = [coinbase_transaction] + @transaction_pool
      transactions = align_transaction(transactions)

      block = Block.new(
        index,
        transactions,
        nonce,
        latest_block.to_hash,
      )

      push_block?(block, miners)
    end

    def push_block?(block : Block, miners : Models::Miners) : Block?
      return nil unless block.valid_as_latest?(self)

      @chain.push(block)

      record_utxo

      if database = @database
        database.push_block(block)
      end

      update_coinbase_transaction(miners)

      block
    end

    def replace_chain(subchain : Models::Chain) : Bool
      return false if subchain.size == 0
      return false if subchain[0].index == 0

      first_index = subchain[0].index - 1
      prev_block = @chain[first_index]

      subchain.each do |block|
        return false unless block.valid_for?(prev_block)
        prev_block = block
      end

      @chain = @chain[0..first_index].concat(subchain)

      @utxo.clear
      @utxo.record(@chain)

      record_utxo

      if database = @database
        database.replace_chain(@chain)
      end

      true
    end

    def add_transaction(transaction : Transaction)
      @transaction_pool << transaction
    end

    def align_transaction(transactions : Array(Transaction))
      return [] of Transaction if transactions.size == 0

      selected_transactions = [transactions[0]]

      transactions[1..-1].each_with_index do |transaction, idx|
        transaction.valid?(self, latest_index, false, selected_transactions)
        transaction.prev_hash = selected_transactions[-1].to_hash

        selected_transactions << transaction
      rescue e : Exception
        transactions.delete(transaction)
      end

      selected_transactions
    end

    def get_amount_unconfirmed(address : String, transactions : Array(Transaction)? = nil) : Int64
      @utxo.get_unconfirmed(address, transactions)
    end

    def get_amount(address : String) : Int64
      @utxo.get(address)
    end

    def latest_block : Block
      @chain[-1]
    end

    def latest_index : Int64
      latest_block.index
    end

    def subchain(from : Int64)
      return nil if @chain.size < from

      @chain[from..-1]
    end

    def record_utxo
      @utxo.record(@chain)
    end

    def genesis_block : Block
      genesis_index = 0_i64
      genesis_transactions = [] of Transaction
      genesis_nonce = 0_u64
      genesis_prev_hash = "genesis"

      Block.new(
        genesis_index,
        genesis_transactions,
        genesis_nonce,
        genesis_prev_hash,
      )
    end

    def create_coinbase_transaction(miners : Models::Miners) : Transaction
      rewards_total = Blockchain.served_amount(latest_index)

      miners_nonces_size = miners.reduce(0) { |sum, m| sum + m[:nonces].size }
      miners_rewards_total = prec((rewards_total * 3_i64) / 4_i64)
      miners_recipients = miners.map { |m|
        amount = (miners_rewards_total * m[:nonces].size) / miners_nonces_size
        {address: m[:address], amount: amount}
      }

      node_reccipient = {
        address: @wallet.address,
        amount:  prec(rewards_total - miners_recipients.reduce(0_i64) { |sum, m| sum + m[:amount] }),
      }

      senders = [] of Models::Sender # No senders

      Transaction.new(
        Transaction.create_id,
        "head",
        senders,
        [node_reccipient] + miners_recipients,
        "0", # message
        "0", # prev_hash
        "0", # sign_r
        "0", # sign_s
      )
    end

    def create_unsigned_transaction(action, senders, recipients, message) : Transaction
      Transaction.new(
        Transaction.create_id,
        action,
        senders,
        recipients,
        message,
        "0", # prev_hash
        "0", # sign_r
        "0", # sign_s
      )
    end

    def self.served_amount(index) : Int64
      div = (index / 10000).to_i
      return 10000_i64 if div == 0
      (10000 / div).to_i64
    end

    def headers
      @chain.map { |block| block.to_header }
    end

    def block_index(transaction_id : String) : Int64?
      @utxo.index(transaction_id)
    end

    include Hashes
    include Consensus
    include Common::Num
  end
end
