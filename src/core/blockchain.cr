# Copyright © 2017-2020 The Axentro Core developers
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

require "./blockchain/*"
require "./blockchain/block/*"
require "./blockchain/chain/*"
require "./blockchain/rewards/*"
require "./dapps"

module ::Axentro::Core
  class Blockchain
    TOKEN_DEFAULT = Core::DApps::BuildIn::UTXO::DEFAULT

    SLOW_BLOCKS_PER_HOUR = 3600_i64 / Consensus::POW_TARGET_SPACING_SECS

    SECURITY_LEVEL_PERCENTAGE        = 20_i64
    STARTING_BLOCKS_TO_CHECK_ON_SYNC = 50_i64
    FINAL_BLOCKS_TO_CHECK_ON_SYNC    = 50_i64

    alias SlowHeader = NamedTuple(
      index: Int64,
      nonce: BlockNonce,
      prev_hash: String,
      merkle_tree_root: String,
      timestamp: Int64,
      difficulty: Int32,
    )

    getter chain : Chain = [] of (SlowBlock | FastBlock)
    getter wallet : Wallet
    getter max_miners : Int32

    @blocks_to_hold : Int64
    @security_level_percentage : Int64
    @node : Node?
    @mining_block : SlowBlock?
    @block_reward_calculator = BlockRewardCalculator.init
    @max_miners : Int32
    @is_standalone : Bool

    def initialize(@wallet : Wallet, @database : Database, @developer_fund : DeveloperFund?, security_level_percentage : Int64?, @max_miners : Int32, @is_standalone : Bool)
      initialize_dapps
      SlowTransactionPool.setup
      FastTransactionPool.setup
      MinerNoncePool.setup

      @security_level_percentage = security_level_percentage || SECURITY_LEVEL_PERCENTAGE
      info "Security Level Percentage used for blockchain validation is #{@security_level_percentage}"

      hours_to_hold = ENV.has_key?("AXE_TESTING") ? 2 : 48
      @blocks_to_hold = (SLOW_BLOCKS_PER_HOUR * hours_to_hold).to_i64
    end

    def database
      @database
    end

    def setup(@node : Node)
      setup_dapps

      restore_from_database(@database)

      unless node.is_private_node?
        spawn process_fast_transactions
      end
    end

    def database
      @database
    end

    def blocks_to_hold
      @blocks_to_hold
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

    private def get_starting_slow_block_index(database : Database, highest_index : Int64)
      # starting index is backed off from last slow block index by N days worth of even-numbered blocks
      starting_index = (highest_index - @blocks_to_hold * 2) + 2
      starting_index = starting_index > 0 ? starting_index : 0_i64
      debug "number of blocks to hold in memory: #{@blocks_to_hold}"
      debug "starting index for SLOW database fetch: #{starting_index}"
      starting_index
    end

    private def restore_from_database(database : Database)
      total_blocks = database.total_blocks
      highest_index = database.highest_index_of_kind(BlockKind::SLOW)
      starting_index = get_starting_slow_block_index(database, highest_index)
      info "start loading blockchain from #{database.path}"
      info "there are #{total_blocks} blocks recorded"
      info "starting at slow block index: #{starting_index}"
      info "highest slow index: #{highest_index}"

      import_slow_blocks(database, starting_index, highest_index)

      highest_index = database.highest_index_of_kind(BlockKind::FAST)
      starting_timestamp = chain.size > 1 ? chain[1].timestamp : 0_i64
      starting_index = database.lowest_index_after_time(starting_timestamp, BlockKind::FAST)

      info "starting at fast block index: #{starting_index}"
      info "highest fast index: #{highest_index}"
      import_fast_blocks(database, starting_index, highest_index)

      if @chain.size == 0
        push_genesis if @is_standalone && @chain.size == 0
      else
        refresh_mining_block(block_difficulty(self))
      end

      dapps_record
    end

    def import_slow_blocks(database, starting_index, highest_index)
      block_counter = 0
      current_index = starting_index
      slow_indexes = (current_index..highest_index).select(&.even?)
      slow_indexes.unshift(0_i64) if (slow_indexes.size == 0) || (slow_indexes[0] != 0_i64)
      slow_indexes.each do |ci|
        current_index = ci
        _block = database.get_block(current_index)
        if _block
          if block_counter > Consensus::HISTORY_LOOKBACK
            break unless _block.valid?(self, true)
          end
          verbose "restoring from database: index #{_block.index} of kind #{_block.kind}"
          @chain.push(_block)
        end
        progress "block ##{current_index} was imported", current_index, slow_indexes.max
        block_counter += 1
      end
    rescue e : Exception
      error "Error could not restore slow blocks from database"
      error e.message.not_nil! if e.message
      database.delete_blocks(current_index.not_nil!)
    ensure
      push_genesis if @is_standalone && @chain.size == 0
    end

    def import_fast_blocks(database, starting_index, highest_index)
      current_index = starting_index
      fast_indexes = (current_index..highest_index).select(&.odd?)
      fast_block_insert_location = 1
      fast_indexes.each do |ci|
        current_index = ci
        _block = database.get_block(current_index)
        if _block
          break unless _block.valid?(self, true)
          debug "restoring from database: index #{_block.index} of kind #{_block.kind}"
          if fast_block_insert_location >= @chain.size
            debug "Pushing new fast block"
            @chain.push(_block)
          else
            debug "Inserting new fast block"
            @chain.insert(fast_block_insert_location, _block)
          end
          fast_block_insert_location += 2
        end
        progress "block ##{current_index} was imported", current_index, fast_indexes.max
      end
    rescue e : Exception
      error "Error could not restore fast blocks from database"
      error e.message.not_nil! if e.message
      database.delete_blocks(current_index.not_nil!)
    end

    def valid_nonce?(block_nonce : BlockNonce) : SlowBlock?
      return mining_block.with_nonce(block_nonce) if mining_block.with_nonce(block_nonce).valid_nonce?(mining_block_difficulty)
      nil
    end

    def valid_block?(block : SlowBlock | FastBlock, skip_transactions : Bool = false, doing_replace : Bool = false) : SlowBlock? | FastBlock?
      case block
      when SlowBlock
        return block if block.valid?(self, skip_transactions, doing_replace)
      when FastBlock
        return block if block.valid?(self, skip_transactions, doing_replace)
      end
      nil
    end

    def mining_block_difficulty : Int32
      return ENV["AX_SET_DIFFICULTY"].to_i if ENV.has_key?("AX_SET_DIFFICULTY")
      the_mining_block = @mining_block
      if the_mining_block
        the_mining_block.difficulty
      else
        latest_slow_block.difficulty
      end
    end

    def mining_block_difficulty_miner : Int32
      return ENV["AX_SET_DIFFICULTY"].to_i if ENV.has_key?("AX_SET_DIFFICULTY")
      block_difficulty_to_miner_difficulty(mining_block_difficulty)
    end

    def replace_block(block : SlowBlock | FastBlock)
      target_index = @chain.index { |b| b.index == block.index }
      if target_index
        @chain[target_index] = block
        @database.replace_block(block)
      else
        warning "replacement block location not found in local chain"
      end
    end

    def push_slow_block(block : SlowBlock)
      _push_block(block)
      clean_slow_transactions

      debug "after clean_transactions, now calling refresh_mining_block in push_block"
      refresh_mining_block(block_difficulty(self))
      block
    end

    def trim_chain_in_memory
      slow_blocks = @chain.select(&.is_slow_block?).last(@blocks_to_hold)
      debug "trim chain, slow block count: #{slow_blocks.size}"
      cutoff_timestamp = slow_blocks[0].timestamp
      debug "trim chain, 1st block index to hold: #{slow_blocks[0].index} cutoff timestamp is: #{cutoff_timestamp}"
      if cutoff_timestamp != 0
        debug "chain size before deletions: #{@chain.size}"
        @chain.reverse.each { |blk|
          if (blk.timestamp != 0) && (blk.timestamp < cutoff_timestamp)
            debug "Deleting block index: #{blk.index} with timestamp: #{blk.timestamp}"
            @chain.delete(blk)
          end
        }
        debug "chain size after deletions: #{@chain.size}"
      end
    end

    private def _push_block(block : SlowBlock | FastBlock)
      @chain.push(block)
      debug "sending #{block.kind} block to DB with timestamp of #{block.timestamp}"
      @database.push_block(block)
      @chain.sort_by! { |blk| blk.index }
      dapps_record
      trim_chain_in_memory
    end

    def replace_chain(_slow_subchain : Chain?, _fast_subchain : Chain?) : Bool
      dapps_clear_record
      slow_result = replace_slow_blocks(_slow_subchain)
      fast_result = replace_fast_blocks(_fast_subchain)

      @chain.sort_by!(&.index)

      trim_chain_in_memory

      clean_slow_transactions
      clean_fast_transactions

      debug "calling refresh_mining_block in replace_chain"
      refresh_mining_block(block_difficulty(self))

      [slow_result, fast_result].includes?(true)
    end

    def get_random_block_ids(max_slow_block_id : Int64, max_fast_block_id : Int64)
      the_indexes = [] of Int64
      number_of_slow_block_ids = ((max_slow_block_id / 2) / (100_i64 / @security_level_percentage)).to_i64
      number_of_fast_block_ids = (((max_fast_block_id + 1) / 2) / (100_i64 / @security_level_percentage)).to_i64
      (1_i64..number_of_slow_block_ids).step do
        randy = Random.new.rand(0_i64..max_slow_block_id)
        randy += 1 if (randy % 2) != 0
        the_indexes << randy
      end
      (1_i64..number_of_fast_block_ids).step do
        randy = Random.new.rand(0_i64..max_fast_block_id)
        randy += 1 if (randy % 2) == 0
        the_indexes << randy
      end
      the_indexes
    end

    def get_hash_of_block_hashes(block_ids : Array(Int64))
      concatenated_hashes = ""
      block_ids.each do |id|
        _block = database.get_block(id)
        if _block
          concatenated_hashes += _block.prev_hash
        else
          warning "expected block id #{id} not found in database"
        end
      end
      debug "Size of concatednated of block prev_hashes to be hashed: #{concatenated_hashes.size}"
      sha256(concatenated_hashes)
    end

    def create_slow_indexes_to_check(incoming_chain)
      the_indexes = [] of Int64
      return the_indexes if @security_level_percentage == 100_i64
      if (incoming_chain.size > STARTING_BLOCKS_TO_CHECK_ON_SYNC + FINAL_BLOCKS_TO_CHECK_ON_SYNC) && (incoming_chain.size > (@chain.size / 4))
        (0_i64..STARTING_BLOCKS_TO_CHECK_ON_SYNC).step(2) { |b| the_indexes << b }
        number_of_elements = (incoming_chain.size - (STARTING_BLOCKS_TO_CHECK_ON_SYNC + FINAL_BLOCKS_TO_CHECK_ON_SYNC)) / (100_i64 / @security_level_percentage)
        index_of_last_incoming_block = incoming_chain[-1].index
        starting_random_block = STARTING_BLOCKS_TO_CHECK_ON_SYNC * 2
        final_random_block = index_of_last_incoming_block - (FINAL_BLOCKS_TO_CHECK_ON_SYNC * 2)
        debug "starting random block is: #{starting_random_block}"
        debug "final random block is: #{final_random_block}"
        debug "number of elements is: #{number_of_elements}"
        (0_i64..number_of_elements.to_i64).step do
          randy = Random.new.rand(starting_random_block..final_random_block)
          randy += 1 if (randy % 2) != 0
          the_indexes << randy
        end
        (final_random_block..index_of_last_incoming_block).step(2) { |b| the_indexes << b }
      end
      the_indexes
    end

    def create_fast_indexes_to_check(incoming_chain)
      the_indexes = [] of Int64
      return the_indexes if @security_level_percentage == 100_i64
      if (incoming_chain.size > STARTING_BLOCKS_TO_CHECK_ON_SYNC + FINAL_BLOCKS_TO_CHECK_ON_SYNC) && (incoming_chain.size > (@chain.size / 4))
        (1_i64..STARTING_BLOCKS_TO_CHECK_ON_SYNC).step(2) { |b| the_indexes << b }
        number_of_elements = (incoming_chain.size - (STARTING_BLOCKS_TO_CHECK_ON_SYNC + FINAL_BLOCKS_TO_CHECK_ON_SYNC)) / (100_i64 / @security_level_percentage)
        index_of_last_incoming_block = incoming_chain[-1].index
        starting_random_block = (STARTING_BLOCKS_TO_CHECK_ON_SYNC * 2) + 1_i64
        final_random_block = index_of_last_incoming_block - (FINAL_BLOCKS_TO_CHECK_ON_SYNC * 2)
        debug "starting random block is: #{starting_random_block}"
        debug "final random block is: #{final_random_block}"
        debug "number of elements is: #{number_of_elements}"
        (0_i64..number_of_elements.to_i64).step do
          randy = Random.new.rand(starting_random_block..final_random_block)
          randy += 1 if (randy % 2) == 0
          the_indexes << randy
        end
        (final_random_block..index_of_last_incoming_block).step(2) { |b| the_indexes << b }
      end
      the_indexes
    end

    private def replace_slow_blocks(slow_subchain)
      return false if slow_subchain.nil?
      result = true
      indexes_for_validity_checking = create_slow_indexes_to_check(slow_subchain)

      slow_subchain.not_nil!.sort_by(&.index).each do |block|
        # running the valid block test only on a subset of blocks for speed on sync
        index = block.index
        if (indexes_for_validity_checking.size == 0) || indexes_for_validity_checking.includes?(index)
          debug "doing valid check on block #{index}"
          block.valid?(self)
        end

        target_index = @chain.index { |b| b.index == index }
        target_index ? (@chain[target_index] = block) : @chain << block
        @database.replace_block(block)

        progress "slow block ##{index} was synced", index, slow_subchain.not_nil!.map(&.index).max

        dapps_record
      rescue e : Exception
        error "found invalid slow block while syncing slow blocks at index #{index}.. deleting all blocks from invalid and up"
        error "the reason:"
        error e.message.not_nil!
        result = false
        if index
          @database.delete_blocks(index)
          @chain.each_index { |i|
            debug "gonna delete at index #{i}"
            @chain.delete_at(i) if @chain[i].index >= index
          }
          dapps_clear_record
        end
        break
      end
      result
    end

    private def replace_fast_blocks(fast_subchain)
      return false if fast_subchain.nil?
      result = true
      indexes_for_validity_checking = create_fast_indexes_to_check(fast_subchain)
      info "started syncing fast blocks"
      fast_subchain.not_nil!.sort_by(&.index).each do |block|
        # running the valid block test only on a subset of blocks for speed on sync
        index = block.index
        if (indexes_for_validity_checking.size == 0) || indexes_for_validity_checking.includes?(index)
          debug "doing valid check on block #{index}"
          block.valid?(self)
        end

        target_index = @chain.index { |b| b.index == index }
        target_index ? (@chain[target_index] = block) : @chain << block
        @database.replace_block(block)

        progress "fast block ##{index} was synced", index, fast_subchain.not_nil!.map(&.index).max

        dapps_record
      rescue e : Exception
        error "found invalid fast block while syncing fast blocks at index #{index}.. deleting all blocks from invalid and up"
        error "the reason:"
        error e.message.not_nil!
        result = false
        if index
          @database.delete_blocks(index)
          @chain.each_index { |i|
            debug "gonna delete at index #{i}"
            @chain.delete_at(i) if @chain[i].index >= index
          }
          dapps_clear_record
        end
        break
      end
      result
    end

    def add_transaction(transaction : Transaction, with_spawn : Bool = true)
      with_spawn ? spawn { _add_transaction(transaction) } : _add_transaction(transaction)
    end

    private def _add_transaction(transaction : Transaction)
      if transaction.valid_common?
        if transaction.kind == TransactionKind::FAST
          if node.i_am_a_fast_node? && node.fast_node_is_online?
            debug "adding fast transaction to pool: #{transaction.id}"
            FastTransactionPool.add(transaction)
          else
            debug "chain is not mature enough for FAST transactions so adding to slow transaction pool: #{transaction.id}"
            transaction.kind = TransactionKind::SLOW
            SlowTransactionPool.add(transaction)
          end
        else
          SlowTransactionPool.add(transaction)
        end
        node.wallet_info_controller.update_wallet_information([transaction])
      end
    rescue e : Exception
      rejects.record_reject(transaction.id, Rejects.address_from_senders(transaction.senders), e)
      node.wallet_info_controller.update_wallet_information([transaction])
    end

    def add_miner_nonce(miner_nonce : MinerNonce, with_spawn : Bool = true)
      with_spawn ? spawn { _add_miner_nonce(miner_nonce) } : _add_miner_nonce(miner_nonce)
    end

    private def _add_miner_nonce(miner_nonce : MinerNonce)
      if valid_nonce?(miner_nonce.value)
        debug "adding miner nonce to pool: #{miner_nonce.value}"
        MinerNoncePool.add(miner_nonce) if MinerNoncePool.find(miner_nonce).nil?
      end
    rescue e : Exception
      warning "nonce was not added to pool due to: #{e}"
    end

    def miner_nonce_pool
      MinerNoncePool
    end

    def latest_block : SlowBlock | FastBlock
      @chain[-1]
    end

    def has_no_blocks? : Bool
      @chain.size <= 0
    end

    def latest_slow_block : SlowBlock
      slow_blocks = @chain.select(&.is_slow_block?)
      return slow_blocks[0].as(SlowBlock) if slow_blocks.size < 1
      slow_blocks[-1].as(SlowBlock)
    end

    def latest_slow_block_when_replacing : SlowBlock
      slow_blocks = @chain.select(&.is_slow_block?)
      return slow_blocks[0].as(SlowBlock) if slow_blocks.size < 1
      slow_blocks[-2].as(SlowBlock)
    end

    def latest_fast_block_when_replacing : FastBlock
      fast_blocks = @chain.select(&.is_fast_block?)
      debug "number of fast blocks when replace attempted: #{fast_blocks.size}"
      return fast_blocks[0].as(FastBlock) if fast_blocks.size == 1
      fast_blocks[-2].as(FastBlock)
    end

    def latest_index : Int64
      latest_block.index
    end

    def get_latest_index_for_slow
      return 0_i64 if has_no_blocks?
      index = latest_slow_block.index
      index.even? ? index + 2 : index + 1
    end

    def subchain_slow(from : Int64) : Chain
      @database.get_slow_blocks(from)
    end

    private def get_genesis_block_transactions
      @developer_fund ? DeveloperFund.transactions(@developer_fund.not_nil!.get_config) : [] of Transaction
    end

    def genesis_block : SlowBlock
      genesis_index = 0_i64
      genesis_transactions = get_genesis_block_transactions
      genesis_nonce = "0"
      genesis_prev_hash = "genesis"
      genesis_timestamp = 0_i64
      genesis_difficulty = Consensus::DEFAULT_DIFFICULTY_TARGET
      address = "genesis"

      SlowBlock.new(
        genesis_index,
        genesis_transactions,
        genesis_nonce,
        genesis_prev_hash,
        genesis_timestamp,
        genesis_difficulty,
        address
      )
    end

    def transactions_for_address(address : String, page : Int32 = 0, page_size : Int32 = 20, actions : Array(String) = [] of String) : Array(Transaction)
      # TODO - we don't want to load the entire db here - instead use a combination of in memory chain + database query
      # TODO: Change this database request to something more sophisticated that filters out blocks that don't have txns with the address
      chain = @database.get_blocks(0_i64)
      chain
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

    def pending_miner_nonces : MinerNonces
      MinerNoncePool.all
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

    def replace_with_block_from_peer(block : SlowBlock | FastBlock)
      replace_block(block)
      debug "replace transactions in indices array that were in the block being replaced with those from the replacement block"
      dapps_clear_record
      debug "cleaning the transactions because of the replacement"
      case block
      when SlowBlock
        clean_slow_transactions_used_in_block(block)
      when FastBlock
        clean_fast_transactions_used_in_block(block)
      end
      debug "refreshing mining block after accepting new block from peer"
      refresh_mining_block(block_difficulty(self)) if block.kind == "SLOW"
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
      MinerNoncePool.delete_embedded

      transactions = align_slow_transactions(coinbase_transaction, coinbase_amount)
      timestamp = __timestamp

      wallet = node.get_wallet
      address = wallet.address

      debug "We are in refresh_mining_block, the next block will have a difficulty of #{difficulty}"

      @mining_block = SlowBlock.new(
        the_latest_index,
        transactions,
        "0",
        latest_slow_block.to_hash,
        timestamp,
        difficulty,
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
        rejects.record_reject(t.id, Rejects.address_from_senders(t.senders), e)
        node.wallet_info_controller.update_wallet_information([t])

        SlowTransactionPool.delete(t)
      end
      debug "exited align_slow_transactions with embedded_slow_transactions size: #{embedded_slow_transactions.size}"

      aligned_transactions
    end

    def create_coinbase_slow_transaction(coinbase_amount : Int64, miners : NodeComponents::MinersManager::Miners) : Transaction
      # TODO - simple solution for now - but should move to it's own class for calculating rewards

      miners_nonces = MinerNoncePool.embedded
      miners_rewards_total = (coinbase_amount * 3_i64) / 4_i64

      miners_recipients = miners_nonces.group_by { |mn| mn.address }.map do |address, nonces|
        amount = (miners_rewards_total * nonces.size) / miners_nonces.size
        {address: address, amount: amount.to_i64}
      end.to_a.flatten.reject { |m| m[:amount] == 0 }

      node_recipient = {
        address: @wallet.address,
        amount:  coinbase_amount - miners_recipients.reduce(0_i64) { |sum, m| sum + m[:amount] },
      }

      senders = [] of Transaction::Sender # No senders
      recipients = miners_rewards_total > 0 ? [node_recipient] + miners_recipients : [] of Transaction::Recipient

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
      @block_reward_calculator.reward_for_block(index) # + total_fees(transactions)
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
        rejects.record_reject(t.id, Rejects.address_from_senders(t.senders), e)
        node.wallet_info_controller.update_wallet_information([t])
      end

      SlowTransactionPool.lock
      SlowTransactionPool.replace(replace_transactions)
    end

    def replace_miner_nonces(miner_nonces : Array(MinerNonce))
      replace_miner_nonces = [] of MinerNonce

      miner_nonces.each do |mn|
        mn = MinerNoncePool.find(mn) || mn
        if valid_nonce?(mn.value)
          replace_miner_nonces << mn
        end
      rescue e : Exception
        warning "nonce was not added to pool due to: #{e}"
      end

      MinerNoncePool.lock
      MinerNoncePool.replace(replace_miner_nonces)
    end

    def clean_slow_transactions_used_in_block(block : SlowBlock)
      SlowTransactionPool.lock
      transactions = pending_slow_transactions.reject { |t| block.find_transaction(t.id) == true }.select(&.is_slow_transaction?)
      SlowTransactionPool.replace(transactions)
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
    include NonceModels
    include Common::Timestamp
  end
end
