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

module ::Axentro::Core::BlockValidator
  extend self

  include Axentro::Common
  include Logger

  def validate_slow(block : SlowBlock, blockchain : Blockchain, skip_transactions : Bool = false, doing_replace : Bool = false) : ValidatedSlowBlock
    if block.index == 0_i64
      validate_genesis(block)
    else
      validate_slow_block(block, blockchain, skip_transactions, doing_replace)
    end
  end

  def validate_fast(block : FastBlock, blockchain : Blockchain, skip_transactions : Bool = false, doing_replace : Bool = false) : ValidatedFastBlock
    validate_fast_block(block, blockchain, skip_transactions, doing_replace)
  end

  def validate_genesis(block : SlowBlock)
    BlockValidator::Rules.rule_genesis(block)
    ValidatedSlowBlock.new(true, block)
  rescue e : Axentro::Common::AxentroException
    ValidatedSlowBlock.new(false, block, e.message || "unknown error")
  rescue e : Exception
    error("#{e.class}: #{e.message || "unknown error"}\n#{e.backtrace.join("\n")}")
    ValidatedSlowBlock.new(false, block, "unexpected error: #{e.message || "unknown error"}")
  end

  def validate_slow_block(block : SlowBlock, blockchain : Blockchain, skip_transactions : Bool = false, doing_replace : Bool = false) : ValidatedSlowBlock
    chain_network = blockchain.database.chain_network_kind
    block_network = Address.get_network_from_address(block.address)

    prev_block_index = block.index - 2_i64
    _prev_block = blockchain.database.get_previous_slow_from(prev_block_index)
    raise AxentroException.new("(slow_block::valid?) error finding previous slow block: #{prev_block_index} for current block: #{block.index}") if _prev_block.nil?
    prev_block = _prev_block.not_nil!.as(SlowBlock)

    BlockValidator::Rules.rule_network_type(chain_network, block_network)

    BlockValidator::Rules.rule_prev_block_slow_index(doing_replace, blockchain, block.index)

    BlockValidator::Rules.rule_prev_hash(block, prev_block)

    BlockValidator::Rules.rule_slow_transactions(skip_transactions, block.transactions, blockchain, block.index)

    BlockValidator::Rules.rule_timestamp(block.timestamp, prev_block, 0_i64)

    BlockValidator::Rules.rule_difficulty(block)

    BlockValidator::Rules.rule_merkle_tree(block)

    ValidatedSlowBlock.new(true, block)
  rescue e : Axentro::Common::AxentroException
    ValidatedSlowBlock.new(false, block, e.message || "unknown error")
  rescue e : Exception
    error("#{e.class}: #{e.message || "unknown error"}\n#{e.backtrace.join("\n")}")
    ValidatedSlowBlock.new(false, block, "unexpected error: #{e.message || "unknown error"}")
  end

  def validate_fast_block(block : FastBlock, blockchain : Blockchain, skip_transactions : Bool = false, doing_replace : Bool = false) : ValidatedFastBlock
    chain_network = blockchain.database.chain_network_kind
    block_network = Address.get_network_from_address(block.address)

    prev_block_index = block.index - 2_i64
    _prev_block = blockchain.database.get_block(prev_block_index)

    raise AxentroException.new("(fast_block::valid?) error finding previous slow block: #{prev_block_index} for current block: #{block.index}") if _prev_block.nil?
    prev_block = _prev_block.not_nil!.as(FastBlock)

    BlockValidator::Rules.rule_fast_signature(block)

    BlockValidator::Rules.rule_network_type(chain_network, block_network)

    BlockValidator::Rules.rule_prev_block_fast_index(doing_replace, blockchain, block.index)

    BlockValidator::Rules.rule_prev_hash(block, prev_block)

    BlockValidator::Rules.rule_fast_transactions(skip_transactions, block.transactions, blockchain, block.index)

    BlockValidator::Rules.rule_timestamp(block.timestamp, prev_block, 30_000_i64)

    BlockValidator::Rules.rule_merkle_tree(block)

    ValidatedFastBlock.new(true, block)
  rescue e : Axentro::Common::AxentroException
    ValidatedFastBlock.new(false, block, e.message || "unknown error")
  rescue e : Exception
    error("#{e.class}: #{e.message || "unknown error"}\n#{e.backtrace.join("\n")}")
    ValidatedFastBlock.new(false, block, "unexpected error: #{e.message || "unknown error"}")
  end

  module Rules
    extend self

    def rule_genesis(block)
      raise AxentroException.new("Invalid Genesis Index: index has to be '0' for genesis block: #{block.index}") if block.index != 0
      raise AxentroException.new("Invalid Genesis Nonce: nonce has to be '0' for genesis block: #{block.nonce}") if block.nonce != "0"
      raise AxentroException.new("Invalid Genesis Previous Hash: prev_hash has to be 'genesis' for genesis block: #{block.prev_hash}") if block.prev_hash != "genesis"
      raise AxentroException.new("Invalid Genesis Difficulty: difficulty has to be '#{Consensus::MINER_DIFFICULTY_TARGET}' for genesis block: #{block.difficulty}") if block.difficulty != Consensus::MINER_DIFFICULTY_TARGET
      raise AxentroException.new("Invalid Genesis Address: address has to be 'genesis' for genesis block") if block.address != "genesis"
    end

    def rule_network_type(chain_network, block_network)
      if chain_network && block_network != chain_network
        raise AxentroException.new("Invalid block network type: incoming block is of type: #{block_network[:name]} but chain is of type: #{chain_network.not_nil![:name]}")
      end
    end

    def rule_prev_block_slow_index(doing_replace, blockchain, current_block_index)
      unless doing_replace
        latest_slow_index = blockchain.get_latest_index_for_slow
        raise AxentroException.new("Index Mismatch: the current block index: #{current_block_index} should match the latest slow block index: #{latest_slow_index}") if current_block_index != latest_slow_index
      end
    end

    def rule_prev_block_fast_index(doing_replace, blockchain, current_block_index)
      unless doing_replace
        latest_slow_index = blockchain.get_latest_index_for_fast
        raise AxentroException.new("Index Mismatch: the current block index: #{current_block_index} should match the latest fast block index: #{latest_slow_index}") if current_block_index != latest_slow_index
      end
    end

    def rule_prev_hash(block, prev_block)
      _prev_hash = block.prev_hash
      # exception occured with this block during switch to new mining system
      # hardcoding an exception for now and figure out a good way to deal with it in future
      if block.index == 99948_i64
        _prev_hash = "2ad3af4b045fde25b584ec98ff65392231b252d9fd4e263c4945c9ae7582f9b4"
      end
      raise AxentroException.new("Invalid Previous Slow Block Hash: for current index: #{block.index} the slow block prev_hash is invalid: (prev index: #{prev_block.index}) #{prev_block.to_hash} != #{_prev_hash}") if prev_block.to_hash != _prev_hash
    end

    def rule_slow_transactions(skip_transactions, transactions, blockchain, current_block_index)
      unless skip_transactions
        vt = validate_slow_transactions(transactions, blockchain, current_block_index)
        raise AxentroException.new(vt.failed.first.reason) if vt.failed.size != 0
      end
    end

    def rule_fast_transactions(skip_transactions, transactions, blockchain, current_block_index)
      unless skip_transactions
        vt = validate_fast_transactions(transactions, blockchain, current_block_index)
        raise AxentroException.new(vt.failed.first.reason) if vt.failed.size != 0
      end
    end

    def rule_fast_signature(block)
      valid_signature = KeyUtils.verify_signature(block.hash, block.signature, block.public_key)
      raise AxentroException.new("Invalid Block Signature: the current block index: #{block.index} has an invalid signature") unless valid_signature
    end

    def rule_timestamp(block_timestamp, prev_block, padding)
      next_timestamp = __timestamp + padding
      prev_timestamp = prev_block.timestamp

      if prev_timestamp > block_timestamp || next_timestamp < block_timestamp
        raise AxentroException.new("Invalid Timestamp: #{block_timestamp} " +
                                   "(timestamp should be bigger than #{prev_timestamp} and smaller than #{next_timestamp})")
      end
    end

    def rule_difficulty(block)
      if block.difficulty > 0
        raise AxentroException.new("Invalid Nonce: #{block.nonce} for difficulty #{block.difficulty}") unless block.calculate_pow_difficulty(block.to_hash, block.nonce, block.difficulty) >= block.block_difficulty_to_miner_difficulty(block.difficulty)
      end
    end

    def rule_merkle_tree(block)
      merkle_tree_root = block.calculate_merkle_tree_root(block.transactions)

      if merkle_tree_root != block.merkle_tree_root
        raise AxentroException.new("Invalid Merkle Tree Root: (expected #{block.merkle_tree_root} but got #{merkle_tree_root})")
      end
    end

    private def validate_slow_transactions(transactions : Array(Transaction), blockchain : Blockchain, current_block_index : Int64) : ValidatedTransactions
      result = SlowTransactionPool.find_all(transactions)
      slow_transactions = result.found + result.not_found

      vt = TransactionValidator.validate_common(slow_transactions, blockchain.network_type)

      coinbase_transactions = vt.passed.select(&.is_coinbase?)
      body_transactions = vt.passed.reject(&.is_coinbase?)

      vt.concat(TransactionValidator.validate_coinbase(coinbase_transactions, body_transactions, blockchain, current_block_index))
      vt.concat(TransactionValidator.validate_embedded(coinbase_transactions + body_transactions, blockchain))
      vt
    end

    private def validate_fast_transactions(transactions : Array(Transaction), blockchain : Blockchain, current_block_index : Int64) : ValidatedTransactions
      result = FastTransactionPool.find_all(transactions)
      fast_transactions = result.found + result.not_found

      vt = TransactionValidator.validate_common(fast_transactions, blockchain.network_type)

      coinbase_transactions = vt.passed.select(&.is_coinbase?)
      body_transactions = vt.passed.reject(&.is_coinbase?)

      vt.concat(TransactionValidator.validate_coinbase(coinbase_transactions, body_transactions, blockchain, current_block_index))
      vt.concat(TransactionValidator.validate_embedded(coinbase_transactions + body_transactions, blockchain))
      vt
    end
  end

  struct ValidatedSlowBlock
    getter valid : Bool
    getter block : SlowBlock
    getter reason : String

    def initialize(@valid, @block, @reason = ""); end
  end

  struct ValidatedFastBlock
    getter valid : Bool
    getter block : FastBlock
    getter reason : String

    def initialize(@valid, @block, @reason = ""); end
  end
end
