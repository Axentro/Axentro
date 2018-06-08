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

require "./blockchain/consensus"
require "./blockchain/*"
require "./dapps"

module ::Sushi::Core
  class Blockchain
    TOKEN_DEFAULT = Core::DApps::BuildIn::UTXO::DEFAULT

    alias Chain = Array(Block)
    alias Header = NamedTuple(
      index: Int64,
      nonce: UInt64,
      prev_hash: String,
      merkle_tree_root: String,
      timestamp: Int64,
      difficulty: Int32,
    )

    alias Transactions = Array(Transaction)

    getter chain : Chain = Chain.new
    getter wallet : Wallet

    @node : Node?
    @queue : BlockQueue::Queue? # todo (deprecate)

    def initialize(@wallet : Wallet, @database : Database? = nil)
      initialize_dapps

      TransactionPool.setup
    end

    def setup(@node : Node)
      @queue = BlockQueue::Queue.create_instance(self)

      setup_dapps

      if database = @database
        restore_from_database(database)
      else
        set_genesis
      end
    end

    def node
      @node.not_nil!
    end

    def queue
      @queue.not_nil!
    end

    def set_genesis
      @chain.push(genesis_block)

      dapps_record

      if database = @database
        database.push_block(genesis_block)
      end
    end

    def restore_from_database(database : Database)
      info "start loding blockchain from #{database.path}"
      info "there are #{database.max_index + 1} blockes recorded"

      current_index = 0_i64

      loop do
        _block = database.get_block(current_index)

        break unless block = _block
        break unless block.valid_as_latest?(self, true)

        @chain.push(block)

        dapps_record

        current_index += 1

        progress "block ##{current_index} was imported", current_index, database.max_index
      end
    rescue e : Exception
      error "an error happens during restoring a blockchain from database"
      error e.message.not_nil! if e.message

      database.delete_blocks(current_index.not_nil!)
    ensure
      set_genesis if @chain.size == 0
    end

    def clean_transactions
      transactions = pending_transactions.reject { |t| indices.get(t.id) }

      TransactionPool.replace(transactions)
    end

    def valid_block?(nonce : UInt64, miners : NodeComponents::MinersManager::Miners) : Block?
      return nil unless latest_block.valid_nonce?(nonce)
      index = @chain.size.to_i64

      coinbase_transaction = create_coinbase_transaction(miners)
      coinbase_amount = latest_block.coinbase_amount

      # transactions = pending_transactions
      # transactions = [coinbase_transaction] + transactions
      # transactions = align_transactions(transactions) # todo

      transactions = align_transactions(coinbase_transaction, coinbase_amount)

      timestamp = __timestamp

      difficulty = block_difficulty(timestamp, latest_block)

      Block.new(
        index,
        transactions,
        nonce,
        latest_block.to_hash,
        timestamp,
        difficulty,
      )
    end

    def valid_block?(block : Block) : Block?
      return nil unless block.valid_as_latest?(self)

      block
    end

    def block_difficulty_latest : Int32
      latest_block.difficulty
    end

    def miner_difficulty_latest : Int32
      Math.max(block_difficulty_latest - 1, 1)
    end

    def push_block(block : Block)
      @chain.push(block)

      dapps_record

      if database = @database
        database.push_block(block)
      end

      clean_transactions
      block
    end

    def replace_chain(_subchain : Chain?) : Bool
      return false unless subchain = _subchain
      return false if subchain.size == 0
      return false if @chain.size == 0

      first_index = subchain[0].index

      if first_index == 0
        @chain = [] of Block
      else
        @chain = @chain[0..first_index - 1]
      end

      dapps_clear_record

      subchain.each_with_index do |block, i|
        block.valid_as_latest?(self)
        @chain << block

        progress "block ##{block.index} was imported", i + 1, subchain.size

        dapps_record
      rescue e : Exception
        error "found invalid block while syncing a blocks"
        error "the reason:"
        error e.message.not_nil!

        break
      end

      if database = @database
        database.replace_chain(@chain)
      end

      true
    end

    def add_transaction(transaction : Transaction)
      TransactionPool.add(transaction)
    end

    def align_transactions(coinbase_transaction : Transaction, coinbase_amount : Int64)
      TransactionPool.align(coinbase_transaction, coinbase_amount)

      if response = TransactionPool.receive
        content = TXP_RES_ALIGN.from_json(response)

        aligned_transactions = content.transactions
        aligned_transactions.each_with_index do |t, idx|
          transaction_valid_dapps?(t, aligned_transactions[0..idx-1]) if idx > 0
        rescue e : Exception
          warning "invalid transaction found, will be removed from the pool"
          warning e.message.not_nil! if e.message

          TransactionPool.delete(t)
        end

        return aligned_transactions
      end

      raise "failed to get aligned transactions from pool"
    end

    # def align_transactions(transactions : Array(Transaction))
    #   return [] of Transaction if transactions.size == 0
    #  
    #   selected_transactions = [transactions[0]]
    #  
    #   # Get aligned transactions from transaction pool
    #   #
    #   # step 2
    #   # - ~~ validate for dApps ~~
    #   #
    #   transactions[1..-1].each_with_index do |transaction, idx|
    #     transaction.prev_hash = selected_transactions[-1].to_hash
    #     # todo
    #     # transaction.valid?(self, selected_transactions)
    #     coinbase_amount = latest_block.coinbase_amount
    #     transaction.valid_without_dapps?(coinbase_amount, selected_transactions)
    #  
    #     transaction_valid_dapps?(transaction, selected_transactions)
    #  
    #     selected_transactions << transaction
    #   rescue e : Exception
    #     warning "invalid transaction found, will be removed from the pool"
    #     warning e.message.not_nil! if e.message
    #  
    #     rejects.record_reject(transaction.id, e)
    #  
    #     TransactionPool.delete(transaction)
    #   end
    #  
    #   selected_transactions
    # end

    def latest_block : Block
      @chain[-1]
    end

    def latest_index : Int64
      latest_block.index
    end

    def subchain(from : Int64) : Chain?
      return nil if @chain.size < from

      @chain[from..-1]
    end

    def genesis_block : Block
      genesis_index = 0_i64
      genesis_transactions = [] of Transaction
      genesis_nonce = 0_u64
      genesis_prev_hash = "genesis"
      genesis_timestamp = 0_i64
      genesis_difficulty = 3

      Block.new(
        genesis_index,
        genesis_transactions,
        genesis_nonce,
        genesis_prev_hash,
        genesis_timestamp,
        genesis_difficulty,
      )
    end

    def create_coinbase_transaction(miners : NodeComponents::MinersManager::Miners) : Transaction
      rewards_total = latest_block.coinbase_amount

      miners_nonces_size = miners.reduce(0) { |sum, m| sum + m[:context][:nonces].size }
      miners_rewards_total = (rewards_total * 3_i64) / 4_i64
      miners_recipients = if miners_nonces_size > 0
                            miners.map { |m|
                              amount = (miners_rewards_total * m[:context][:nonces].size) / miners_nonces_size
                              {address: m[:context][:address], amount: amount}
                            }.reject { |m| m[:amount] == 0 }
                          else
                            [] of NamedTuple(address: String, amount: Int64)
                          end

      node_reccipient = {
        address: @wallet.address,
        amount:  rewards_total - miners_recipients.reduce(0_i64) { |sum, m| sum + m[:amount] },
      }

      senders = [] of Transaction::Sender # No senders

      Transaction.new(
        Transaction.create_id,
        "head",
        senders,
        [node_reccipient] + miners_recipients,
        "0",           # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        __timestamp,   # timestamp
        1,             # scaled
      )
    end

    def headers
      @chain.map { |block| block.to_header }
    end

    def transactions_for_address(address : String, page : Int32 = 0, page_size : Int32 = 20, actions : Array(String) = [] of String) : Array(Transaction)
      @chain
        .reverse
        .map { |block| block.transactions }
        .flatten
        .select { |transaction| actions.empty? || actions.includes?(transaction.action) }
        .select { |transaction|
        transaction.senders.any? { |sender| sender[:address] == address } ||
          transaction.recipients.any? { |recipient| recipient[:address] == address }
      }.skip(page*page_size).first(page_size)
    end

    def available_actions : Array(String)
      @dapps.map { |dapp| dapp.transaction_actions }.flatten
    end

    #
    # todo
    # move to Transaction
    #
    def transaction_valid_dapps?(transaction : Transaction, transactions : Transactions)
      dapps.each do |dapp|
        if dapp.transaction_related?(transaction.action) && transactions.size > 0
          dapp.valid?(transaction, transactions)
        end
      end
    end

    def pending_transactions : Transactions
      TransactionPool.all

      if response = TransactionPool.receive
        return TXP_RES_ALL.from_json(response).transactions
      end

      Transactions.new
    end

    private def dapps_record
      @dapps.each do |dapp|
        dapp.record(@chain)
      end
    end

    private def dapps_clear_record
      @dapps.each do |dapp|
        dapp.clear
        dapp.record(@chain)
      end
    end

    include DApps
    include Hashes
    include Logger
    include Protocol
    include Consensus
    include TransactionModels
    include Common::Timestamp
  end
end
