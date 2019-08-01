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

    getter chain : Chain = Chain.new
    getter wallet : Wallet

    @node : Node?
    @mining_block : Block?

    def initialize(@wallet : Wallet, @database : Database?, @premine : Premine?)
      initialize_dapps

      TransactionPool.setup
    end

    def setup(@node : Node)
      setup_dapps

      if database = @database
        restore_from_database(database)
      else
        push_genesis
      end
    end

    def node
      @node.not_nil!
    end

    def push_genesis
      push_block(genesis_block)
    end

    def restore_from_database(database : Database)
      info "start loading blockchain from #{database.path}"
      info "there are #{database.max_index} blocks recorded"

      current_index = 0_i64
      loop do
        _block = database.get_block(current_index)
        break unless block = _block
        break unless block.valid?(self, true)
        @chain.push(block)
        current_index += 1
        progress "block ##{current_index} was imported", current_index, database.max_index
      end
      if @chain.size == 0
        push_genesis
      else
        refresh_mining_block(block_difficulty(self))
      end

      dapps_record

    rescue e : Exception
      error "Error could not restore blockchain from database"
      error e.message.not_nil! if e.message
      warning "removing invalid blocks from database"
      database.delete_blocks(current_index.not_nil!)
    ensure
      push_genesis if @chain.size == 0
    end

    def clean_transactions
      TransactionPool.lock
      transactions = pending_transactions.reject { |t| indices.get(t.id) }
      TransactionPool.replace(transactions)
    end

    def valid_nonce?(nonce : UInt64) : Block?
      return mining_block.with_nonce(nonce) if mining_block.with_nonce(nonce).valid_nonce?(mining_block_difficulty)
      nil
    end

    def valid_block?(block : Block) : Block?
      return block if block.valid?(self)
      nil
    end

    def mining_block_difficulty : Int32
      the_mining_block = @mining_block
      if the_mining_block
        the_mining_block.difficulty
      else
        latest_block.difficulty
      end
    end

    def mining_block_difficulty_miner : Int32
      block_difficulty_to_miner_difficulty(mining_block_difficulty)
    end

    def push_block(block : Block)
      @chain.push(block)
      if database = @database
        debug "sending to DB, block with nonce of #{block.nonce} and timestamp of #{block.timestamp}"
        database.push_block(block)
      end

      debug "in node.push_block, before dapps_record"
      dapps_record
      debug "after dapps record, before clean transactions"
      clean_transactions

      debug "after clean_transactions, now calling refresh_mining_block in push_block"
      refresh_mining_block(block_difficulty(self))

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
        block.valid?(self)
        @chain << block

        progress "block ##{block.index} was imported", i + 1, subchain.size

        dapps_record
      rescue e : Exception
        error "found invalid block while syncing blocks"
        error "the reason:"
        error e.message.not_nil!

        break
      end

      push_genesis if @chain.size == 0
      if database = @database
        database.replace_chain(@chain)
      end

      clean_transactions

      debug "calling refresh_mining_block in replace_chain"
      refresh_mining_block(block_difficulty(self))

      true
    end

    def replace_transactions(transactions : Array(Transaction))
      replace_transactions = [] of Transaction

      transactions.each_with_index do |t, i|
        progress "validating transaction #{t.short_id}", i + 1, transactions.size

        t = TransactionPool.find(t) || t
        t.valid_common?

        replace_transactions << t
      rescue e : Exception
        rejects.record_reject(t.id, e)
      end

      TransactionPool.lock
      TransactionPool.replace(replace_transactions)
    end

    def add_transaction(transaction : Transaction, with_spawn : Bool = true)
      with_spawn ? spawn { _add_transaction(transaction) } : _add_transaction(transaction)
    end

    private def _add_transaction(transaction : Transaction)
      if transaction.valid_common?
        TransactionPool.add(transaction)
      end
    rescue e : Exception
      rejects.record_reject(transaction.id, e)
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
      genesis_transactions = @premine ? Premine.transactions(@premine.not_nil!.get_config) : [] of Transaction
      genesis_nonce = 0_u64
      genesis_prev_hash = "genesis"
      genesis_timestamp = Time.now.to_unix
      genesis_difficulty = Consensus::DEFAULT_DIFFICULTY_TARGET

      Block.new(
        genesis_index,
        genesis_transactions,
        genesis_nonce,
        genesis_prev_hash,
        genesis_timestamp,
        genesis_difficulty,
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

    def pending_transactions : Transactions
      TransactionPool.all
    end

    def embedded_transactions : Transactions
      TransactionPool.embedded
    end

    def mining_block : Block
      debug "calling refresh_mining_block in mining_block" unless @mining_block
      refresh_mining_block(Consensus::DEFAULT_DIFFICULTY_TARGET) unless @mining_block
      @mining_block.not_nil!
    end

   def get_premine_total_amount : Int64
     @premine ? @premine.not_nil!.get_total_amount : 0_i64
   end

    def refresh_mining_block(difficulty)
      coinbase_amount = coinbase_amount(latest_index + 1, embedded_transactions, get_premine_total_amount)
      coinbase_transaction = create_coinbase_transaction(coinbase_amount, node.miners)
      transactions = align_transactions(coinbase_transaction, coinbase_amount)
      timestamp = __timestamp

      debug "We are in refresh_mining_block, the next block will have a difficulty of #{difficulty}"

      @mining_block = Block.new(
        latest_index + 1,
        transactions,
        0_u64,
        latest_block.to_hash,
        timestamp,
        difficulty,
      )

      node.miners_broadcast
    end

    def align_transactions(coinbase_transaction : Transaction, coinbase_amount : Int64) : Transactions
      aligned_transactions = [coinbase_transaction]

      debug "entered align_transactions with embedded_transactions size: #{embedded_transactions.size}"
      embedded_transactions.each do |t|
        t.prev_hash = aligned_transactions[-1].to_hash
        t.valid_as_embedded?(self, aligned_transactions)

        aligned_transactions << t
      rescue e : Exception
        rejects.record_reject(t.id, e)

        TransactionPool.delete(t)
      end
      debug "exited align_transactions with embedded_transactions size: #{embedded_transactions.size}"

      aligned_transactions
    end

    def create_coinbase_transaction(coinbase_amount : Int64, miners : NodeComponents::MinersManager::Miners) : Transaction
      miners_nonces_size = miners.reduce(0) { |sum, m| sum + m[:context][:nonces].size }
      miners_rewards_total = (coinbase_amount * 3_i64) / 4_i64
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
        amount:  coinbase_amount - miners_recipients.reduce(0_i64) { |sum, m| sum + m[:amount] },
      }

      senders = [] of Transaction::Sender # No senders

      recipients = miners_rewards_total > 0 ? [node_reccipient] + miners_recipients : [] of Transaction::Recipient

      Transaction.new(
        Transaction.create_id,
        "head",
        senders,
        recipients,
        "0",           # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        __timestamp,   # timestamp
        1,             # scaled
      )
    end

    RR = 2546479089470325

    def coinbase_amount(index : Int64, transactions, premine_total_value : Int64) : Int64
      premine_index = premine_as_index(premine_total_value, index)
      index_index = (premine_index + index) * (premine_index + index)
      return total_fees(transactions) if index_index > RR
      Math.sqrt(RR - index_index).to_i64
    end

    def premine_as_index(premine_value : Int64, current_index : Int64) : Int64
      return 0_i64 if (premine_value <= 0_i64 || current_index > 0)
      accumulated_value = 0_i64
      index = 0_i64
      (0_i64..(Math.sqrt(RR).to_i64)).each do |_|
        value = Math.sqrt(RR - (index * index)).to_i64
        accumulated_value = accumulated_value + value
        break if accumulated_value >= premine_value
        index = index + 1
      end
      debug "accumulated_value: #{accumulated_value} -> premine_value: #{premine_value}, index: #{index}"
      index
    end

    def total_fees(transactions) : Int64
      return 0_i64 if transactions.size < 2
      transactions.reduce(0_i64) { |fees, transaction| fees + transaction.total_fees }
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
