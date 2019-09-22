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
require "./blockchain/block/*"
require "./blockchain/chain/*"
require "./dapps"

module ::Sushi::Core
  class Blockchain
    TOKEN_DEFAULT = Core::DApps::BuildIn::UTXO::DEFAULT

    alias SlowHeader = NamedTuple(
      index: Int64,
      nonce: UInt64,
      prev_hash: String,
      merkle_tree_root: String,
      timestamp: Int64,
      difficulty: Int32,
    )

    getter chain : Chain = [] of (SlowBlock | FastBlock)
    getter wallet : Wallet

    @node : Node?
    @mining_block : SlowBlock?
    @block_reward_calculator = BlockRewardCalculator.init

    def initialize(@wallet : Wallet, @database : Database?, @developer_fund : DeveloperFund?)
      initialize_dapps
      SlowTransactionPool.setup
      FastTransactionPool.setup
    end

    def setup(@node : Node)
      setup_dapps

      if database = @database
        restore_from_database(database)
      else
        push_genesis
      end

      spawn process_fast_transactions
      spawn leadership_contest
    end

    def node
      @node.not_nil!
    end

    private def push_genesis
      push_slow_block(genesis_block)
    end

    def get_genesis_block
      @chain.first
    end

    private def restore_from_database(database : Database)
      total_blocks = database.total_blocks
      highest_index = database.highest_index
      info "start loading blockchain from #{database.path}"
      info "there are #{total_blocks} blocks recorded"

      current_index = 0_i64
      (0..highest_index).each do |_|
        _block = database.get_block(current_index)
        if _block
          break unless _block.valid?(self, true)
          debug "restoring from database: #{_block.index} of kind #{_block.kind}"
          @chain.push(_block)
        end

        current_index += 1
        progress "block ##{current_index} was imported", current_index, highest_index
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

    def valid_nonce?(nonce : UInt64) : SlowBlock?
      return mining_block.with_nonce(nonce) if mining_block.with_nonce(nonce).valid_nonce?(mining_block_difficulty)
      nil
    end

    def valid_block?(block : SlowBlock | FastBlock) : SlowBlock? | FastBlock?
      return block if block.valid?(self)
      nil
    end

    def mining_block_difficulty : Int32
      return ENV["SC_SET_DIFFICULTY"].to_i if ENV.has_key?("SC_SET_DIFFICULTY")
      the_mining_block = @mining_block
      if the_mining_block
        the_mining_block.difficulty
      else
        latest_slow_block.difficulty
      end
    end

    def mining_block_difficulty_miner : Int32
      return ENV["SC_SET_DIFFICULTY"].to_i if ENV.has_key?("SC_SET_DIFFICULTY")
      block_difficulty_to_miner_difficulty(mining_block_difficulty)
    end

    def push_slow_block(block : SlowBlock)
      _push_block(block)
      clean_slow_transactions

      debug "after clean_transactions, now calling refresh_mining_block in push_block"
      refresh_mining_block(block_difficulty(self))
      block
    end

    private def _push_block(block : SlowBlock | FastBlock)
      @chain.push(block)
      @chain.sort_by! { |blk| blk.index }
      if database = @database
        debug "sending #{block.kind} block to DB with timestamp of #{block.timestamp}"
        database.push_block(block)
      end

      debug "in blockchain._push_block, before dapps_record"
      dapps_record
      debug "after dapps record, before clean transactions"
    end

    def replace_chain(_slow_subchain : Chain?, _fast_subchain : Chain?) : Bool
      return false if @chain.size == 0

      replacement = [] of SlowBlock | FastBlock
      replacement += _slow_subchain unless _slow_subchain.nil?
      replacement += _fast_subchain unless _fast_subchain.nil?
      replacement = replacement.flatten

      return false if replacement.size == 0

      dapps_clear_record

      replacement.sort_by! { |block| block.index }

      replacement.each do |block|
        block.valid?(self)

        index = block.index
        @chain[index]? ? (@chain[index] = block) : @chain << block

        progress "block ##{index} was imported/synced (replace_chain)", index, replacement.size

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

      clean_slow_transactions
      clean_fast_transactions

      debug "calling refresh_mining_block in replace_chain"
      refresh_mining_block(block_difficulty(self))

      true
    end

    def add_transaction(transaction : Transaction, with_spawn : Bool = true)
      with_spawn ? spawn { _add_transaction(transaction) } : _add_transaction(transaction)
    end

    private def _add_transaction(transaction : Transaction)
      if transaction.valid_common?
        if transaction.kind == TransactionKind::FAST
          debug "adding fast transaction to pool: #{transaction.id}"
          FastTransactionPool.add(transaction)
        else
          SlowTransactionPool.add(transaction)
        end
      end
    rescue e : Exception
      rejects.record_reject(transaction.id, e)
    end

    def latest_block : SlowBlock | FastBlock
      @chain[-1]
    end

    def latest_slow_block : SlowBlock
      slow_blocks = @chain.select(&.is_slow_block?)
      return slow_blocks[0].as(SlowBlock) if slow_blocks.size < 1
      slow_blocks[-1].as(SlowBlock)
    end

    def latest_index : Int64
      latest_block.index
    end

    def get_latest_index_for_slow
      index = latest_slow_block.index
      index.even? ? index + 2 : index + 1
    end

    def subchain_slow(from : Int64) : Chain?
      slow_chain = @chain.select(&.is_slow_block?)
      return nil if slow_chain.size < from

      slow_chain[from..-1]
    end

    def genesis_block : SlowBlock
      genesis_index = 0_i64
      genesis_transactions = @developer_fund ? DeveloperFund.transactions(@developer_fund.not_nil!.get_config) : [] of Transaction
      genesis_nonce = 0_u64
      genesis_prev_hash = "genesis"
      genesis_timestamp = Time.now.to_unix
      genesis_difficulty = Consensus::DEFAULT_DIFFICULTY_TARGET
      address = "genesis"

      SlowBlock.new(
        genesis_index,
        genesis_transactions,
        genesis_nonce,
        genesis_prev_hash,
        genesis_timestamp,
        genesis_difficulty,
        BlockKind::SLOW,
        address
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

    def pending_slow_transactions : Transactions
      SlowTransactionPool.all
    end

    def pending_fast_transactions : Transactions
      FastTransactionPool.all
    end

    def embedded_slow_transactions : Transactions
      SlowTransactionPool.embedded
    end

    def embedded_fast_transactions : Transactions
      FastTransactionPool.embedded
    end

    def mining_block : SlowBlock
      debug "calling refresh_mining_block in mining_block" unless @mining_block
      refresh_mining_block(Consensus::DEFAULT_DIFFICULTY_TARGET) unless @mining_block
      @mining_block.not_nil!
    end

    def refresh_mining_block(difficulty)
      refresh_slow_pending_block(difficulty)
    end

    private def refresh_slow_pending_block(difficulty)
      the_latest_index = get_latest_index_for_slow
      coinbase_amount = coinbase_slow_amount(the_latest_index, embedded_slow_transactions)
      coinbase_transaction = create_coinbase_slow_transaction(coinbase_amount, node.miners)
      transactions = align_slow_transactions(coinbase_transaction, coinbase_amount)
      timestamp = __timestamp

      wallet = node.get_wallet
      address = wallet.address

      debug "We are in refresh_mining_block, the next block will have a difficulty of #{difficulty}"

      @mining_block = SlowBlock.new(
        the_latest_index,
        transactions,
        0_u64,
        latest_slow_block.to_hash,
        timestamp,
        difficulty,
        BlockKind::SLOW,
        address
      )

      node.miners_broadcast
    end

    def align_slow_transactions(coinbase_transaction : Transaction, coinbase_amount : Int64) : Transactions
      aligned_transactions = [coinbase_transaction]

      debug "entered align_slow_transactions with embedded_slow_transactions size: #{embedded_slow_transactions.size}"
      embedded_slow_transactions.each do |t|
        t.prev_hash = aligned_transactions[-1].to_hash
        t.valid_as_embedded?(self, aligned_transactions)

        aligned_transactions << t
      rescue e : Exception
        rejects.record_reject(t.id, e)

        SlowTransactionPool.delete(t)
      end
      debug "exited align_slow_transactions with embedded_slow_transactions size: #{embedded_slow_transactions.size}"

      aligned_transactions
    end

    def create_coinbase_slow_transaction(coinbase_amount : Int64, miners : NodeComponents::MinersManager::Miners) : Transaction
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
        TransactionKind::SLOW
      )
    end

    def coinbase_slow_amount(index : Int64, transactions) : Int64
      return total_fees(transactions) if index >= @block_reward_calculator.max_blocks
      @block_reward_calculator.reward_for_block(index)
    end

    def total_fees(transactions) : Int64
      return 0_i64 if transactions.size < 2
      transactions.reduce(0_i64) { |fees, transaction| fees + transaction.total_fees }
    end

    def replace_slow_transactions(transactions : Array(Transaction))
      transactions = transactions.select(&.is_slow_transaction?)
      replace_transactions = [] of Transaction

      transactions.each_with_index do |t, i|
        progress "validating slow transaction #{t.short_id}", i + 1, transactions.size

        t = SlowTransactionPool.find(t) || t
        t.valid_common?

        replace_transactions << t
      rescue e : Exception
        rejects.record_reject(t.id, e)
      end

      SlowTransactionPool.lock
      SlowTransactionPool.replace(replace_transactions)
    end

    def clean_slow_transactions
      SlowTransactionPool.lock
      transactions = pending_slow_transactions.reject { |t| indices.get(t.id) }.select(&.is_slow_transaction?)
      SlowTransactionPool.replace(transactions)
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

    include FastChain
    include Block
    include DApps
    include Hashes
    include Logger
    include Protocol
    include Consensus
    include TransactionModels
    include Common::Timestamp
  end
end
