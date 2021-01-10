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
  struct ReplaceBlocksResult
    property index : Int64
    property success : Bool

    def initialize(@index, @success); end
  end

  class Blockchain
    TOKEN_DEFAULT = Core::DApps::BuildIn::UTXO::DEFAULT

    SLOW_BLOCKS_PER_HOUR = 3600_i64 / Consensus::POW_TARGET_SPACING_SECS

    STARTING_BLOCKS_TO_CHECK_ON_SYNC = 50_i64
    FINAL_BLOCKS_TO_CHECK_ON_SYNC    = 50_i64
    FAST_TRANSACTIONS_TO_HOLD        = 10_000

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

    @network_type : String
    @blocks_to_hold : Int64
    @sync_chunk_size : Int32
    @record_nonces : Bool
    @node : Node?
    @mining_block : SlowBlock?
    @block_reward_calculator = BlockRewardCalculator.init
    @max_miners : Int32
    @is_standalone : Bool
    @database_path : String

    def initialize(@network_type : String, @wallet : Wallet, @database_path : String, @database : Database, @developer_fund : DeveloperFund?, @official_nodes : OfficialNodes?, @security_level_percentage : Int64, @sync_chunk_size : Int32, @record_nonces : Bool, @max_miners : Int32, @is_standalone : Bool)
      initialize_dapps
      SlowTransactionPool.setup
      FastTransactionPool.setup(@database_path)
      MinerNoncePool.setup

      info "Security Level Percentage used for blockchain validation is #{@security_level_percentage}"
      info "Blockchain sync chunk size is #{@sync_chunk_size}"

      hours_to_hold = ENV.has_key?("AXE_TESTING") ? 2 : 8
      @blocks_to_hold = (SLOW_BLOCKS_PER_HOUR * hours_to_hold).to_i64
      info "holding #{@blocks_to_hold} slow blocks and 2000 fast blocks in memory"
    end

    def database
      @database
    end

    def network_type
      @network_type
    end

    def setup(@node : Node)
      setup_dapps

      restore_from_database(@database)

      spawn mining_block_tracker

      unless node.is_private_node?
        spawn process_fast_transactions
      end
    end

    # check if the mining is on track
    def mining_block_tracker
      loop do
        spawn do
          slow_block_mining_check
        end
        sleep(2) # check every 2 seconds
      end
    end

    private def slow_block_mining_check
      # if no slow block was mined after 3 mins and there are miners connected then lower the difficulty dynamically
      if node.miners_manager.miners.size > 0
        current_block_timestamp = mining_block.timestamp
        now = __timestamp
        three_minutes_in_ms = 180000

        if (now - current_block_timestamp) > three_minutes_in_ms
          unless mining_block.difficulty <= Consensus::DEFAULT_DIFFICULTY_TARGET
            warning "No block mined within 3 minutes so auto dropping difficulty"
            refresh_slow_pending_block(Consensus::DEFAULT_DIFFICULTY_TARGET)
          end
        end
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

    private def restore_from_database(database : Database)
      total_blocks = database.total_blocks

      info "start loading blockchain from #{database.path}"
      info "there are #{total_blocks} blocks recorded"

      # find most recent 1440 slow block ids
      highest_slow_index = database.highest_index_of_kind(BlockKind::SLOW)
      slow_ids = (0_i64..highest_slow_index).reverse_each.select(&.even?).first(@blocks_to_hold).to_a.reverse

      if slow_ids.size > 0
        starting_slow_index = slow_ids.first
        info "starting at slow block index: #{starting_slow_index}"
        info "highest slow index: #{highest_slow_index}"
        import_slow_blocks(database, slow_ids)
      end

      # find most recent 2000 fast block ids
      highest_fast_index = database.highest_index_of_kind(BlockKind::FAST)
      fast_ids = (0_i64..highest_fast_index).reverse_each.select(&.odd?).first(2000).to_a.reverse

      if fast_ids.size > 0
        starting_fast_index = fast_ids.first
        info "starting at fast block index: #{starting_fast_index}"
        info "highest fast index: #{highest_fast_index}"
        import_fast_blocks(database, fast_ids)
      end

      if @chain.size == 0
        push_genesis if @is_standalone
      else
        refresh_mining_block(block_difficulty(self))
      end

      dapps_record
    end

    def import_slow_blocks(database, indices)
      current_index = indices.first
      slow_blocks = database.get_blocks_by_ids(indices)

      slow_blocks.each_with_index do |block, i|
        current_index = block.index

        # if i > Consensus::HISTORY_LOOKBACK
        #   block.valid?(self, true)
        # end

        # skip transaction checking because it will fail as transaction already in db
        # check after index 2 only as need latest index to be 2 or more
        if i >= 2
          block.valid?(self, true)
        end

        @chain.push(block)
        progress "block ##{current_index} was imported", current_index, slow_blocks.map(&.index).max
      end
    rescue e : Exception
      if current_index
        error "Error could not restore slow blocks from database at index: #{current_index}"
        error e.message || "unknown error while restoring slow blocks from database"
        warning "archiving slow blocks from index #{current_index} and up"
        database.archive_blocks_of_kind(current_index, "restore", Block::BlockKind::SLOW)
        warning "deleting slow blocks from index #{current_index} and up"
        database.delete_blocks_of_kind(current_index, Block::BlockKind::SLOW)
      end
    ensure
      push_genesis if @is_standalone && @chain.size == 0
    end

    def import_fast_blocks(database, indices)
      current_index = indices.first
      fast_blocks = database.get_blocks_by_ids(indices)
      fast_block_insert_location = 1

      fast_blocks.each_with_index do |block, i|
        current_index = block.index
        if i > 0
          break unless block.valid?(self, true)
        end

        if fast_block_insert_location >= @chain.size
          debug "Pushing new fast block"
          @chain.push(block)
        else
          debug "Inserting new fast block"
          @chain.insert(fast_block_insert_location, block)
        end
        fast_block_insert_location += 2

        progress "block ##{current_index} was imported", current_index, fast_blocks.map(&.index).max
      end
    rescue e : Exception
      if current_index
        error "Error could not restore fast blocks from database at index: #{current_index}"
        error e.message || "unknown error while restoring fast blocks from database"
        warning "archiving fast blocks from index #{current_index} and up"
        database.archive_blocks_of_kind(current_index, "restore", Block::BlockKind::FAST)
        warning "deleting fast blocks from index #{current_index} and up"
        database.delete_blocks_of_kind(current_index.not_nil!, Block::BlockKind::FAST)
      end
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
        # validate during replace block
        @database.delete_block(block.index)
        # check block is valid here (including checking transactions) - we are in replace
        block.valid?(self, false, true)
        @database.push_block(block)
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

    def replace_mixed_chain(subchain : Chain?) : ReplaceBlocksResult
      dapps_clear_record
      result = replace_mixed_blocks(subchain)

      @chain.sort_by!(&.index)

      trim_chain_in_memory

      clean_slow_transactions
      clean_fast_transactions

      debug "calling refresh_mining_block in replace_chain"
      refresh_mining_block(block_difficulty(self))

      result
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
      debug "Size of concatendated of block prev_hashes to be hashed: #{concatenated_hashes.size}"
      sha256(concatenated_hashes)
    end

    def create_indexes_to_check(incoming_chain)
      return [] of Int64 if @security_level_percentage == 100_i64
      return [] of Int64 if incoming_chain.empty?
      incoming_indices = incoming_chain.map(&.index)
      max_incoming_block_id = incoming_indices.max
      percentage_as_count = (max_incoming_block_id*@security_level_percentage*0.01).ceil.to_i
      incoming_indices.shuffle.first(percentage_as_count)
    end

    private def replace_mixed_blocks(chain) : ReplaceBlocksResult
      result = ReplaceBlocksResult.new(0_i64, true)

      if chain.nil?
        result.success = false
        return result
      end

      indexes_for_validity_checking = create_indexes_to_check(chain.not_nil!)

      chain.not_nil!.sort_by(&.timestamp).each do |block|
        index = block.index
        result.index = index

        target_index = @chain.index { |b| b.index == index }
        target_index ? (@chain[target_index] = block) : @chain << block

        @database.delete_block(block.index)
        # running the valid block test only on a subset of blocks for speed on sync
        if (indexes_for_validity_checking.size == 0) || indexes_for_validity_checking.includes?(index)
          debug "doing valid check on block #{index}"
          # this valid check is historic and not as latest block
          block.valid?(self, false, true)
        end

        @database.push_block(block)

        progress "block ##{index} was synced", index, chain.not_nil!.map(&.index).max

        dapps_record
      rescue e : Exception
        error "found invalid block while syncing blocks at index #{index}.. deleting all blocks from invalid and up"
        error "the reason:"
        error e.message.not_nil!
        result.success = false
        if index
          @database.archive_blocks(index, "sync")
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
      vt = Validation::Transaction.validate_common([transaction], @network_type)

      # TODO - could reject in bulk also
      vt.failed.each do |ft|
        rejects.record_reject(ft.transaction.id, Rejects.address_from_senders(ft.transaction.senders), ft.reason)
        node.wallet_info_controller.update_wallet_information([ft.transaction])
      end

      vt.passed.each do |_transaction|
        if _transaction.kind == TransactionKind::FAST
          if node.fastnode_is_online?
            if node.i_am_a_fast_node?
              debug "adding fast transaction to pool (I am a fast node): #{_transaction.id}"
              FastTransactionPool.add(_transaction)
            end
          else
            debug "chain is not mature enough for FAST transactions so adding to slow transaction pool: #{_transaction.id}"
            _transaction.kind = TransactionKind::SLOW
            SlowTransactionPool.add(_transaction)
          end
        else
          SlowTransactionPool.add(_transaction)
        end
        node.wallet_info_controller.update_wallet_information([_transaction])
      end
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

    private def get_genesis_block_transactions
      dev_fund = @developer_fund ? DeveloperFund.transactions(@developer_fund.not_nil!.get_config) : [] of Transaction
      official_nodes = @official_nodes ? OfficialNodes.transactions(@official_nodes.not_nil!.get_config, dev_fund) : [] of Transaction
      dev_fund + official_nodes
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

    def available_actions : Array(String)
      OfficialNode.apply_exclusions(@dapps).map { |dapp| dapp.transaction_actions }.flatten
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

    def calculate_coinbase_slow_transaction(coinbase_amount, the_latest_index, embedded_slow_transactions)
      # pay the fees to the fastnode for maintenance (unless there are no more blocks to mine)
      fee = (the_latest_index >= @block_reward_calculator.max_blocks) ? 0_i64 : total_fees(embedded_slow_transactions)
      create_coinbase_slow_transaction(coinbase_amount, fee, node.miners)
    end

    private def refresh_slow_pending_block(difficulty)
      # we don't want to delete any of the miner nonces unless this refresh is for the next block
      # otherwise we loose the nonces for the rewards
      previous_mining_block_index = latest_slow_block.index
      if _prev_mining_block = @mining_block
        previous_mining_block_index = _prev_mining_block.index
      end

      the_latest_index = get_latest_index_for_slow

      coinbase_amount = coinbase_slow_amount(the_latest_index, embedded_slow_transactions)
      coinbase_transaction = calculate_coinbase_slow_transaction(coinbase_amount, the_latest_index, embedded_slow_transactions)

      transactions = align_slow_transactions(coinbase_transaction, coinbase_amount, the_latest_index, embedded_slow_transactions)
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

      latest_hash = @mining_block.not_nil!.to_hash

      # if record nonces is true then write nonces to the db
      if @record_nonces
        miners_nonces = MinerNoncePool.embedded
        miners_nonces.group_by { |mn| mn.address }.map do |_, nonces|
          nonces.each do |nonce|
            database.insert_nonce(Nonce.new(nonce.address, nonce.value, latest_hash, the_latest_index, difficulty, nonce.timestamp))
          end
        end
      end

      # align slow transactions may need to re-calc the rewards so only delete the pool after all calcs are finished
      # only delete the nonces if this refresh is for the next block (otherwise we loose the nonces for the rewards)
      MinerNoncePool.delete_embedded if the_latest_index > previous_mining_block_index

      node.miners_broadcast
    end

    def align_slow_transactions(coinbase_transaction : Transaction, coinbase_amount : Int64, the_latest_index : Int64, embedded_slow_transactions : Array(Transaction)) : Transactions
      transactions = [coinbase_transaction] + embedded_slow_transactions

      # 1. first validate all the embedded transactions without the prev_hash
      vt = Validation::Transaction.validate_common(transactions, @network_type)

      skip_prev_hash_check = true
      vt << Validation::Transaction.validate_embedded(transactions, self, skip_prev_hash_check)

      vt.failed.each do |ft|
        rejects.record_reject(ft.transaction.id, Rejects.address_from_senders(ft.transaction.senders), ft.reason)
        node.wallet_info_controller.update_wallet_information([ft.transaction])
        SlowTransactionPool.delete(ft.transaction)
      end

      # 2. after any transactions have been rejected then - check coinbase and re-create if incorrect
      # validate coinbase and fix it if incorrect (due to rejected transactions)
      vtc = Validation::Transaction.validate_coinbase([coinbase_transaction], vt.passed, self, the_latest_index)
      aligned_transactions = if vtc.failed.size == 0
                               vt.passed
                             else
                               coinbase_amount = coinbase_slow_amount(the_latest_index, vt.passed)
                               coinbase_transaction = calculate_coinbase_slow_transaction(coinbase_amount, the_latest_index, vt.passed)
                               [coinbase_transaction] + vt.passed.reject(&.is_coinbase?)
                             end

      # 3. create all the prev_hashes for the transactions
      sorted_aligned_transactions = [coinbase_transaction] + aligned_transactions.reject(&.is_coinbase?).sort_by(&.timestamp)
      sorted_aligned_transactions.map_with_index do |transaction, index|
        transaction.add_prev_hash((index == 0 ? "0" : sorted_aligned_transactions[index - 1].to_hash))
      end
    end

    def coinbase_recipient_for_fastnode(fee) : Array(Transaction::Recipient)
      fastnodes = official_node.all_fast_impl
      if fastnodes.size > 0 && fee > 0
        return [{
          address: fastnodes.first,
          amount:  fee,
        }]
      end
      [] of Transaction::Recipient
    end

    def create_coinbase_slow_transaction(coinbase_amount : Int64, fee : Int64, miners : NodeComponents::MinersManager::Miners) : Transaction
      # TODO - simple solution for now - but should move to it's own class for calculating rewards
      miners_nonces = MinerNoncePool.embedded
      miners_rewards_total = (coinbase_amount * 3_i64) / 4_i64

      miners_recipients = miners_nonces.group_by { |mn| mn.address }.map do |address, nonces|
        amount = (miners_rewards_total * nonces.size) / miners_nonces.size
        {address: address, amount: amount.to_i64}
      end.to_a.flatten.reject { |m| m[:amount] == 0 }

      recipient_list = [] of Transaction::Recipient
      fastnode_recipient = coinbase_recipient_for_fastnode(fee)

      # if I am the fastnode then should add the fee to the node_recipient if not then use this fastnode_recipient
      node_recipient_amount = coinbase_amount - miners_recipients.reduce(0_i64) { |sum, m| sum + m[:amount] }
      if official_node.i_am_a_fastnode?(@wallet.address)
        recipient_list << {
          address: @wallet.address,
          amount:  node_recipient_amount + fee,
        }
      else
        recipient_list << {
          address: @wallet.address,
          amount:  node_recipient_amount,
        }
        recipient_list += fastnode_recipient
      end

      # if there are no miners_rewards_total -
      senders = [] of Transaction::Sender # No senders
      recipients = miners_rewards_total > 0 ? recipient_list + miners_recipients : [] of Transaction::Recipient

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
        TransactionKind::SLOW,
        TransactionVersion::V1
      )
    end

    def coinbase_slow_amount(index : Int64, transactions) : Int64
      return total_fees(transactions) if index >= @block_reward_calculator.max_blocks
      @block_reward_calculator.reward_for_block(index)
    end

    def total_fees(transactions) : Int64
      transactions.reduce(0_i64) { |fees, transaction| fees + transaction.total_fees }
    end

    def replace_slow_transactions(transactions : Array(Transaction))
      results = SlowTransactionPool.find_all(transactions.select(&.is_slow_transaction?))
      slow_transactions = results.found + results.not_found

      vt = Validation::Transaction.validate_common(slow_transactions, @network_type)

      vt.failed.each do |ft|
        rejects.record_reject(ft.transaction.id, Rejects.address_from_senders(ft.transaction.senders), ft.reason)
        node.wallet_info_controller.update_wallet_information([ft.transaction])
      end

      SlowTransactionPool.lock
      SlowTransactionPool.replace(vt.passed)
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
