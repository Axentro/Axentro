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
require "./blockchain/domain_model/*"
require "./blockchain/validators/*"
require "./blockchain/chain/*"
require "./blockchain/rewards/*"
require "./dapps"
require "./node/components/metrics"

module ::Axentro::Core
  struct ReplaceBlocksResult
    property index : Int64
    property success : Bool

    def initialize(@index, @success); end
  end

  class Blockchain
    TOKEN_DEFAULT = Core::DApps::BuildIn::UTXO::DEFAULT

    alias Header = NamedTuple(
      index: Int64,
      nonce: BlockNonce,
      prev_hash: String,
      merkle_tree_root: String,
      timestamp: Int64,
      difficulty: Int32,
    )

    getter wallet_address : String
    getter max_miners : Int32

    @network_type : String
    @sync_chunk_size : Int32
    @record_nonces : Bool
    @node : Node?
    @mining_block : Block?
    @block_reward_calculator = BlockRewardCalculator.init
    @max_miners : Int32
    @is_standalone : Bool
    @database_path : String

    def initialize(@network_type : String, @wallet : Wallet?, @wallet_address : String, @database_path : String, @database : Database, @developer_fund : DeveloperFund?, @official_nodes : OfficialNodes?, @security_level_percentage : Int64, @sync_chunk_size : Int32, @record_nonces : Bool, @max_miners : Int32, @is_standalone : Bool)
      initialize_dapps
      SlowTransactionPool.setup
      FastTransactionPool.setup(@database_path)
      MinerNoncePool.setup

      info "Security Level Percentage used for blockchain validation is #{@security_level_percentage}"
      info "Blockchain sync chunk size is #{@sync_chunk_size}"
    end

    def database
      @database
    end

    def network_type
      @network_type
    end

    def chain
      @database.get_blocks_via_query("select * from blocks order by timestamp asc limit 250")
    end

    def setup(@node : Node)
      setup_dapps

      if @database.total_blocks == 0
        if @is_standalone
          push_genesis
          refresh_mining_block
        end
      else
        if @is_standalone
          info "validating db for standalone node"
          @database.validate_local_db_blocks
        end
      end
    end

    def database
      @database
    end

    def node
      @node.not_nil!
    end

    private def push_genesis
      push_slow_block(genesis_block)
    end

    def get_genesis_block : Block
      @database.get_block(0).not_nil!.as(Block)
    end

    def valid_nonce?(block_nonce : BlockNonce) : Bool
      mining_block.with_nonce(block_nonce).valid_block_nonce?(mining_block_difficulty)
    end

    def valid_block?(block : Block, skip_transactions : Bool = false, doing_replace : Bool = false) : Block?
      block if block.valid?(self, skip_transactions, doing_replace)
    end

    def mining_block_difficulty : Int32
      return ENV["AX_SET_DIFFICULTY"].to_i if ENV.has_key?("AX_SET_DIFFICULTY")
      the_mining_block = @mining_block
      if the_mining_block
        the_mining_block.difficulty
      else
        @database.get_highest_block_for_kind!(BlockKind::SLOW).difficulty
      end
    end

    def mining_block_difficulty_miner : Int32
      return ENV["AX_SET_DIFFICULTY"].to_i if ENV.has_key?("AX_SET_DIFFICULTY")
      block_difficulty_to_miner_difficulty(mining_block_difficulty)
    end

    def mining_block_difficulty_for_miner(difficulty : Int32) : Int32
      return ENV["AX_SET_DIFFICULTY"].to_i if ENV.has_key?("AX_SET_DIFFICULTY")
      block_difficulty_to_miner_difficulty(difficulty)
    end

    def replace_block(block : Block)
      target_index = chain.index(&.index.==(block.index))
      if target_index
        # validate during replace block
        @database.delete_block(block.index)
        # check block is valid here (including checking transactions) - we are in replace
        block.valid?(self, false, true)
        @database.push_block(block)
      else
        warning "replacement block location not found in local chain"
      end
    end

    def push_slow_block(block : Block)
      _push_block(block)
      clean_slow_transactions
      clean_fast_transactions

      debug "after clean_transactions, now calling refresh_mining_block in push_block"
      refresh_mining_block
      block
    end

    private def _push_block(block : Block)
      debug "sending #{block.kind} block to DB with timestamp of #{block.timestamp}"
      @database.push_block(block)
    end

    def add_transaction(transaction : Transaction, with_spawn : Bool = true)
      with_spawn ? spawn { _add_transaction(transaction) } : _add_transaction(transaction)
    end

    private def _add_transaction(transaction : Transaction)
      vt = TransactionValidator.validate_common([transaction], @network_type)

      # TODO - could reject in bulk also
      vt.failed.each do |ft|
        METRICS_TRANSACTIONS_COUNTER[kind: "rejected"].inc
        rejects.record_reject(ft.transaction.id, Rejects.address_from_senders(ft.transaction.senders), ft.reason)
        node.wallet_info_controller.update_wallet_information([ft.transaction])
      end

      vt.passed.each do |_transaction|
        if _transaction.kind == TransactionKind::FAST
          if node.fastnode_is_online?
            if node.i_am_a_fast_node?
              debug "adding fast transaction to pool (I am a fast node): #{_transaction.id}"
              METRICS_TRANSACTIONS_COUNTER[kind: "fast"].inc
              FastTransactionPool.add(_transaction)
            end
          else
            debug "chain is not mature enough for FAST transactions so adding to slow transaction pool: #{_transaction.id}"
            _transaction.kind = TransactionKind::SLOW
            METRICS_TRANSACTIONS_COUNTER[kind: "slow"].inc
            SlowTransactionPool.add(_transaction)
          end
        else
          METRICS_TRANSACTIONS_COUNTER[kind: "slow"].inc
          SlowTransactionPool.add(_transaction)
        end
        node.wallet_info_controller.update_wallet_information([_transaction])
      end
    end

    def add_miner_nonce(miner_nonce : MinerNonce, with_spawn : Bool = true)
      with_spawn ? spawn { _add_miner_nonce(miner_nonce) } : _add_miner_nonce(miner_nonce)
    end

    private def _add_miner_nonce(miner_nonce : MinerNonce)
      # if valid_nonce?(miner_nonce.value)
      debug "adding miner nonce to pool: #{miner_nonce.value}"
      MinerNoncePool.add(miner_nonce) if MinerNoncePool.find(miner_nonce).nil?
      # end

    rescue e : Exception
      warning "nonce was not added to pool due to: #{e}"
    end

    def miner_nonce_pool
      MinerNoncePool
    end

    private def get_genesis_block_transactions
      dev_fund = @developer_fund ? DeveloperFund.transactions(@developer_fund.not_nil!.get_config) : [] of Transaction
      official_nodes = @official_nodes ? OfficialNodes.transactions(@official_nodes.not_nil!.get_config, dev_fund) : [] of Transaction
      dev_fund + official_nodes
    end

    def genesis_block : Block
      genesis_index = 0_i64
      genesis_transactions = get_genesis_block_transactions
      genesis_nonce = "0"
      genesis_prev_hash = "genesis"
      genesis_timestamp = 0_i64
      genesis_difficulty = Consensus::MINER_DIFFICULTY_TARGET
      kind = BlockKind::SLOW
      address = "genesis"
      public_key = ""
      signature = ""
      hash = ""
      version = BlockVersion::V2
      hash_version = HashVersion::V2
      merkle_tree_root = MerkleTreeCalculator.new(hash_version).calculate_merkle_tree_root(genesis_transactions)
      checkpoint = ""
      mining_version = MiningVersion::V1

      Block.new(
        genesis_index,
        genesis_transactions,
        genesis_nonce,
        genesis_prev_hash,
        genesis_timestamp,
        genesis_difficulty,
        kind,
        address,
        public_key,
        signature,
        hash,
        version,
        hash_version,
        merkle_tree_root,
        checkpoint,
        mining_version
      )
    end

    def available_actions : Array(String)
      OfficialNode.apply_exclusions(@dapps).flat_map(&.transaction_actions)
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

    def replace_with_block_from_peer(block : Block)
      replace_block(block)
      debug "replace transactions in indices array that were in the block being replaced with those from the replacement block"
      debug "cleaning the transactions because of the replacement"
      clean_slow_transactions_used_in_block(block)
      clean_fast_transactions_used_in_block(block)
      debug "refreshing mining block after accepting new block from peer"
      refresh_mining_block if block.kind == "SLOW"
    end

    def mining_block : Block
      debug "calling refresh_mining_block in mining_block" unless @mining_block
      refresh_mining_block unless @mining_block
      @mining_block.not_nil!
    end

    def calculate_coinbase_slow_transaction(coinbase_amount, the_latest_index, embedded_slow_transactions)
      # pay the fees to the fastnode for maintenance (unless there are no more blocks to mine)
      fee = (the_latest_index >= @block_reward_calculator.max_blocks) ? 0_i64 : total_fees(embedded_slow_transactions)
      create_coinbase_slow_transaction(coinbase_amount, fee, node.miners)
    end

    def refresh_mining_block
      # we don't want to delete any of the miner nonces unless this refresh is for the next block
      # otherwise we loose the nonces for the rewards
      latest_slow_block = database.get_highest_block_for_kind!(BlockKind::SLOW)
      previous_mining_block_index = latest_slow_block.index
      previous_mining_block_hash = latest_slow_block.to_hash
      if _prev_mining_block = @mining_block
        previous_mining_block_index = _prev_mining_block.index
        previous_mining_block_hash = _prev_mining_block.to_hash
      end

      the_next_index = latest_slow_block.index + 2

      verbose "previous mining block index: #{previous_mining_block_index}, latest index: #{the_next_index}"

      coinbase_amount = coinbase_slow_amount(the_next_index, embedded_slow_transactions)
      coinbase_transaction = calculate_coinbase_slow_transaction(coinbase_amount, the_next_index, embedded_slow_transactions)

      transactions = align_slow_transactions(coinbase_transaction, coinbase_amount, the_next_index, embedded_slow_transactions)
      timestamp = __timestamp

      checkpoint = @database.get_checkpoint_merkle(the_next_index, BlockKind::SLOW)

      @mining_block = Block.new(
        the_next_index,
        transactions,
        "0",
        latest_slow_block.to_hash,
        timestamp,
        latest_slow_block.difficulty,
        @wallet_address,
        BlockVersion::V2,
        HashVersion::V2,
        checkpoint,
        MiningVersion::V1
      )

      latest_hash = @mining_block.not_nil!.to_hash

      # if record nonces is true then write nonces to the db
      if @record_nonces
        miners_nonces = MinerNoncePool.embedded
        miners_nonces.group_by(&.address).map do |_, nonces|
          nonces.each do |nonce|
            database.insert_nonce(Nonce.new(nonce.address, nonce.value, latest_hash, the_next_index, nonce.difficulty, nonce.timestamp))
          end
        end
      end

      # align slow transactions may need to re-calc the rewards so only delete the pool after all calcs are finished
      # only delete the nonces if this refresh is for the next block (otherwise we lose the nonces for the rewards)
      if the_next_index > previous_mining_block_index
        MinerNoncePool.delete_embedded
      end

      # we only want to broadcast the updated block if the hash has changed.
      if latest_hash != previous_mining_block_hash
        node.miners_broadcast
      end
    end

    def align_slow_transactions(coinbase_transaction : Transaction, coinbase_amount : Int64, the_latest_index : Int64, embedded_slow_transactions : Array(Transaction)) : Transactions
      transactions = [coinbase_transaction] + embedded_slow_transactions

      # 1. first validate all the embedded transactions without the prev_hash
      vt = TransactionValidator.validate_common(transactions, @network_type)

      skip_prev_hash_check = true
      vt.concat(TransactionValidator.validate_embedded(transactions, self, skip_prev_hash_check))

      vt.failed.each do |ft|
        rejects.record_reject(ft.transaction.id, Rejects.address_from_senders(ft.transaction.senders), ft.reason)
        node.wallet_info_controller.update_wallet_information([ft.transaction])
        SlowTransactionPool.delete(ft.transaction)
      end

      # 2. after any transactions have been rejected then - check coinbase and re-create if incorrect
      # validate coinbase and fix it if incorrect (due to rejected transactions)
      vtc = TransactionValidator.validate_coinbase([coinbase_transaction], vt.passed, self, the_latest_index)
      aligned_transactions = if vtc.failed.size == 0
                               vt.passed
                             else
                               coinbase_amount = coinbase_slow_amount(the_latest_index, vt.passed)
                               coinbase_transaction = calculate_coinbase_slow_transaction(coinbase_amount, the_latest_index, vt.passed)
                               [coinbase_transaction] + vt.passed.reject(&.is_coinbase?)
                             end

      # 3. create all the prev_hashes for the transactions
      sorted_aligned_transactions = [coinbase_transaction] + aligned_transactions.reject(&.is_coinbase?).sort_by!(&.timestamp)
      sorted_aligned_transactions.map_with_index do |transaction, index|
        transaction.add_prev_hash((index == 0 ? "0" : sorted_aligned_transactions[index - 1].to_hash))
      end
    end

    def coinbase_recipient_for_fastnode(fee) : Array(Transaction::Recipient)
      fastnodes = official_node.all_fast_impl
      if fastnodes.size > 0 && fee > 0
        return [Recipient.new(fastnodes.first, fee)]
      end
      [] of Transaction::Recipient
    end

    def create_coinbase_slow_transaction(coinbase_amount : Int64, fee : Int64, miners : NodeComponents::MinersManager::Miners) : Transaction
      fastnode_recipient = coinbase_recipient_for_fastnode(fee)
      is_fastnode = official_node.i_am_a_fastnode?(@wallet_address)
      reward_calculator = MinerRewardCalculator.new(MinerNoncePool.embedded, coinbase_amount, fastnode_recipient, is_fastnode, @wallet_address, fee)

      miner_recipients = reward_calculator.miner_rewards_as_recipients
      node_recipient = reward_calculator.node_rewards_as_recipients(miner_recipients)

      senders = [] of Transaction::Sender # No senders
      recipients = reward_calculator.miner_rewards_total > 0 ? node_recipient + miner_recipients : [] of Transaction::Recipient

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

      vt = TransactionValidator.validate_common(slow_transactions, @network_type)

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

    def clean_slow_transactions_used_in_block(block : Block)
      SlowTransactionPool.lock
      transactions = pending_slow_transactions.reject { |t| block.find_transaction(t.id) == true }.select(&.is_slow_transaction?)
      SlowTransactionPool.replace(transactions)
    end

    def clean_slow_transactions
      SlowTransactionPool.lock
      transactions = pending_slow_transactions.reject { |t| indices.get(t.id) }.select(&.is_slow_transaction?)
      SlowTransactionPool.replace(transactions)
    end

    include FastChain
    include DApps
    include Hashes
    include Logger
    include Protocol
    include Consensus
    include TransactionModels
    include NonceModels
    include Common::Timestamp
    include TransactionValidator
    include NodeComponents::Metrics
  end
end
