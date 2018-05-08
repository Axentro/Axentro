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
    )

    getter chain : Chain = Chain.new
    getter wallet : Wallet
    getter transaction_pool = [] of Transaction

    @node : Node?
    @queue : BlockQueue::Queue?

    def initialize(@wallet : Wallet, @database : Database? = nil)
      initialize_dapps
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
      current_index = 0_i64

      loop do
        _block = database.get_block(current_index)

        break unless block = _block
        break unless block.valid_as_latest?(self)

        @chain.push(block)

        dapps_record

        current_index += 1

        progress "  block ##{current_index} was imported\r"
      end
    rescue e : Exception
      error "an error happens during restoring a blockchain from database"
      error e.message.not_nil! if e.message

      database.delete_blocks(current_index.not_nil!)
    ensure
      set_genesis if @chain.size == 0
    end

    def clean_transactions
      @transaction_pool.reject! { |transaction| indices.get(transaction.id) }
    end

    def valid_block?(nonce : UInt64, miners : NodeComponents::MinersManager::Miners) : Block?
      return nil unless latest_block.valid_nonce?(nonce)

      index = @chain.size.to_i64

      coinbase_transaction = create_coinbase_transaction(miners)

      transactions = [coinbase_transaction] + @transaction_pool
      transactions = align_transactions(transactions)

      Block.new(
        index,
        transactions,
        nonce,
        latest_block.to_hash,
      )
    end

    def valid_block?(block : Block) : Block?
      return nil unless block.valid_as_latest?(self)

      block
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

      subchain.each do |block|
        block.valid_as_latest?(self)
        @chain << block

        progress "  block ##{block.index} was imported\r"

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
      @transaction_pool << transaction
    end

    def align_transactions(transactions : Array(Transaction))
      return [] of Transaction if transactions.size == 0

      selected_transactions = [transactions[0]]

      transactions[1..-1].each_with_index do |transaction, idx|
        transaction.prev_hash = selected_transactions[-1].to_hash
        transaction.valid?(self, latest_index, false, selected_transactions)

        selected_transactions << transaction
      rescue e : Exception
        warning "invalid transaction found, will be removed from the pool"
        warning e.message.not_nil! if e.message

        rejects.record_reject(transaction.id, e)

        @transaction_pool.delete(transaction)
      end

      selected_transactions
    end

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

      Block.new(
        genesis_index,
        genesis_transactions,
        genesis_nonce,
        genesis_prev_hash,
      )
    end

    def create_coinbase_transaction(miners : NodeComponents::MinersManager::Miners) : Transaction
      rewards_total = served_amount(latest_index)

      miners_nonces_size = miners.reduce(0) { |sum, m| sum + m[:nonces].size }
      miners_rewards_total = (rewards_total * 3_i64) / 4_i64
      miners_recipients = if miners_nonces_size > 0
                            miners.map { |m|
                              amount = (miners_rewards_total * m[:nonces].size) / miners_nonces_size
                              {address: m[:address], amount: amount}
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
        "0",           # sign_r
        "0",           # sign_s
      )
    end

    def total_fees_of_latest_block : Int64
      return 0_i64 if @chain.size == 0
      return 0_i64 if @chain[-1].transactions.size < 2

      latest_block.transactions[1..-1].reduce(0_i64) { |fees, transaction| fees + transaction.calculate_fee }
    end

    def create_unsigned_transaction(action, senders, recipients, message, token, id = Transaction.create_id) : Transaction
      Transaction.new(
        id,
        action,
        senders,
        recipients,
        message,
        token,
        "0", # prev_hash
        "0", # sign_r
        "0", # sign_s
      )
    end

    def served_amount(index) : Int64
      total_fees = total_fees_of_latest_block
      base = 10000
      div = (index / base).to_i
      return base.to_i64 + total_fees if div == 0
      (base / div).to_i64 + total_fees
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

    include Logger
    include Hashes
    include Consensus
    include DApps
  end
end
