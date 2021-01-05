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

module ::Axentro::Core
  class SlowBlock
    extend Hashes

    include JSON::Serializable
    property index : Int64
    property transactions : Array(Transaction)
    property nonce : BlockNonce
    property prev_hash : String
    property merkle_tree_root : String
    property timestamp : Int64
    property difficulty : Int32
    property kind : BlockKind
    property address : String

    def initialize(
      @index : Int64,
      @transactions : Array(Transaction),
      @nonce : BlockNonce,
      @prev_hash : String,
      @timestamp : Int64,
      @difficulty : Int32,
      @address : String
    )
      raise "index must be even number" if index.odd?
      @merkle_tree_root = calculate_merkle_tree_root
      @kind = BlockKind::SLOW
    end

    def to_s
      debug "SlowBlock index: #{@index}"
      debug "SlowBlock transactions for block #{@index}: #{@transactions.size}"
      debug "SlowBlock nonce for block #{@index}: #{@nonce}"
      debug "SlowBlock prev_hash for block #{@index}: #{@prev_hash}"
      debug "SlowBlock timestamp for block #{@index}: #{@timestamp}"
      debug "SlowBlock difficulty for block #{@index}: #{@difficulty}"
      debug "SlowBlock hash for block #{@index}: #{self.to_hash}"
    end

    def to_header : Blockchain::SlowHeader
      {
        index:            @index,
        nonce:            @nonce,
        prev_hash:        @prev_hash,
        merkle_tree_root: @merkle_tree_root,
        timestamp:        @timestamp,
        difficulty:       @difficulty,
      }
    end

    def to_hash : String
      string = SlowBlockNoTimestamp.from_slow_block(self).to_json
      sha256(string)
    end

    def calculate_merkle_tree_root : String
      return "" if @transactions.size == 0

      current_hashes = @transactions.map { |tx| tx.to_hash }

      loop do
        tmp_hashes = [] of String

        (current_hashes.size / 2).to_i.times do |i|
          tmp_hashes.push(sha256(current_hashes[i*2] + current_hashes[i*2 + 1]))
        end

        tmp_hashes.push(current_hashes[-1]) if current_hashes.size % 2 == 1

        current_hashes = tmp_hashes
        break if current_hashes.size == 1
      end

      ripemd160(current_hashes[0])
    end

    def is_slow_block?
      @kind == BlockKind::SLOW
    end

    def is_fast_block?
      @kind == BlockKind::FAST
    end

    def kind : String
      is_slow_block? ? "SLOW" : "FAST"
    end

    def with_nonce(@nonce : BlockNonce) : SlowBlock
      self
    end

    def valid_nonce?(difficulty : Int32)
      valid_nonce?(self.to_hash, @nonce, difficulty)
    end

    private def validate_transactions(transactions : Array(Transaction), blockchain : Blockchain) : ValidatedTransactions
      result = SlowTransactionPool.find_all(transactions)
      slow_transactions = result.found + result.not_found

      vt = Validation::Transaction.validate_common(slow_transactions, blockchain.network_type)

      coinbase_transactions = vt.passed.select(&.is_coinbase?)
      body_transactions = vt.passed.reject(&.is_coinbase?)

      vt << Validation::Transaction.validate_coinbase(coinbase_transactions, body_transactions, blockchain, @index)
      vt << Validation::Transaction.validate_embedded(coinbase_transactions + body_transactions, blockchain)
      vt
    end

    def valid?(blockchain : Blockchain, skip_transactions : Bool = false, doing_replace : Bool = false) : Bool
      prev_block_index = @index - 2
      _prev_block = blockchain.database.get_block(prev_block_index)

      return valid_as_genesis? if @index == 0_i64
      raise "(slow_block::valid?) error finding previous slow block: #{prev_block_index} for current block: #{@index}" if _prev_block.nil? 
      prev_block = _prev_block.not_nil!.as(SlowBlock)
       
      raise "Invalid Previous Slow Block Hash: for current index: #{@index} the slow block prev_hash is invalid: (prev index: #{prev_block.index}) #{prev_block.to_hash} != #{@prev_hash}" if prev_block.to_hash != @prev_hash

      unless skip_transactions
        vt = validate_transactions(transactions, blockchain)
        raise vt.failed.first.reason if vt.failed.size != 0
      end  

      next_timestamp = __timestamp
      prev_timestamp = prev_block.timestamp

      if prev_timestamp > @timestamp || next_timestamp < @timestamp
        raise "Invalid Timestamp: #{@timestamp} " +
              "(timestamp should be bigger than #{prev_timestamp} and smaller than #{next_timestamp})"
      end
 
      raise "Invalid Nonce: #{@nonce} for difficulty #{@difficulty}" unless self.valid_nonce?(@difficulty) >= block_difficulty_to_miner_difficulty(@difficulty)
      
      difficulty_gap = (@difficulty - prev_block.difficulty).abs
      unless difficulty_gap <= 2
        raise "Invalid difficulty gap between previous block #{prev_block.index} and this block #{@index}, expected gap of no more than 2 but gap was: #{difficulty_gap}"
      end

      merkle_tree_root = calculate_merkle_tree_root

      if merkle_tree_root != @merkle_tree_root
        raise "Invalid Merkle Tree Root: (expected #{@merkle_tree_root} but got #{merkle_tree_root})"
      end

      latest_slow_index = blockchain.get_latest_index_for_slow
      if doing_replace
        latest_slow_index = blockchain.get_latest_index_for_slow - 2
      end
      raise "Index Mismatch: the current block index: #{@index} should match the latest slow block index: #{latest_slow_index}" if @index != latest_slow_index

      # if as_latest
      #   latest_slow_index = blockchain.get_latest_index_for_slow
      #   raise "Index Mismatch: the current block index: #{@index} should match the lastest slow block index: #{latest_slow_index}" if @index != latest_slow_index

      #   difficulty_for_block = block_difficulty(blockchain)
 
      # if @difficulty > 0
      #   if @difficulty != difficulty_for_block
      #     raise "Invalid difficulty: " + "(expected #{difficulty_for_block} but got #{@difficulty})"
      #   end
      # end
      # end
     

      true
    end

    # ameba:disable Metrics/CyclomaticComplexity
    # def valid_as_latest2?(blockchain : Blockchain, skip_transactions : Bool = false, doing_replace : Bool = false) : Bool

    #   puts "DOING_REPLACE: #{doing_replace}"

    #   if doing_replace
    #     prev_block = blockchain.latest_slow_block_when_replacing
    #     latest_slow_index = blockchain.get_latest_index_for_slow - 2
    #   else
    #     prev_block = blockchain.latest_slow_block
    #     latest_slow_index = blockchain.get_latest_index_for_slow
    #   end

    #   puts "this: #{self.index}, prev_block: #{prev_block.index}, latest: #{latest_slow_index}"

    #   unless skip_transactions
    #     vt = validate_transactions(transactions, blockchain)
    #     raise vt.failed.first.reason if vt.failed.size != 0
    #   end

    #   raise "Index Mismatch: the current block index: #{@index} should match the lastest slow block index: #{latest_slow_index}" if @index != latest_slow_index
    #   raise "Invalid Previous Slow Block Hash: for current index: #{@index} the slow block prev_hash is invalid: (prev index: #{prev_block.index}) #{prev_block.to_hash} != #{@prev_hash}" if prev_block.to_hash != @prev_hash

    #   next_timestamp = __timestamp
    #   prev_timestamp = prev_block.timestamp

    #   if prev_timestamp > @timestamp || next_timestamp < @timestamp
    #     raise "Invalid Timestamp: #{@timestamp} " +
    #           "(timestamp should be bigger than #{prev_timestamp} and smaller than #{next_timestamp})"
    #   end

    #   if doing_replace
    #     difficulty_for_block = blockchain.latest_slow_block.difficulty
    #   else
    #     difficulty_for_block = block_difficulty(blockchain)
    #   end
    #   verbose "Calculated a difficulty of #{difficulty_for_block} for block #{@index} in validity check"
    #   difficulty_for_block = prev_block.index == 0 ? @difficulty : difficulty_for_block

    #   if @difficulty > 0
    #     if @difficulty != difficulty_for_block
    #       raise "Invalid difficulty: " + "(expected #{difficulty_for_block} but got #{@difficulty})"
    #     end
    #     raise "Invalid Nonce: #{@nonce} for difficulty #{@difficulty}" unless self.valid_nonce?(@difficulty) >= block_difficulty_to_miner_difficulty(@difficulty)
    #   end

    #   merkle_tree_root = calculate_merkle_tree_root

    #   if merkle_tree_root != @merkle_tree_root
    #     raise "Invalid Merkle Tree Root: (expected #{@merkle_tree_root} but got #{merkle_tree_root})"
    #   end

    #   true
    # end

    def valid_as_genesis? : Bool
      raise "Invalid Genesis Index: index has to be '0' for genesis block: #{@index}" if @index != 0
      raise "Invalid Genesis Nonce: nonce has to be '0' for genesis block: #{@nonce}" if @nonce != "0"
      raise "Invalid Genesis Previous Hash: prev_hash has to be 'genesis' for genesis block: #{@prev_hash}" if @prev_hash != "genesis"
      raise "Invalid Genesis Difficulty: difficulty has to be '#{Consensus::DEFAULT_DIFFICULTY_TARGET}' for genesis block: #{@difficulty}" if @difficulty != Consensus::DEFAULT_DIFFICULTY_TARGET
      raise "Invalid Genesis Address: address has to be 'genesis' for genesis block" if @address != "genesis"
      true
    end

    def find_transaction(transaction_id : String) : Transaction?
      @transactions.find { |t| t.id.starts_with?(transaction_id) }
    end

    def set_transactions(txns : Transactions)
      @transactions = txns
      verbose "Number of transactions in block: #{txns.size}"
      @merkle_tree_root = calculate_merkle_tree_root
    end

    include Block
    include Hashes
    include Logger
    include Protocol
    include Consensus
    include Common::Timestamp
    include NonceModels
  end

  class SlowBlockNoTimestamp
    include JSON::Serializable
    property index : Int64
    property transactions : Array(Transaction)
    property nonce : String
    property prev_hash : String
    property merkle_tree_root : String
    property difficulty : Int32
    property address : String

    def self.from_slow_block(b : SlowBlock)
      SlowBlockNoTimestamp.new(b.index, b.transactions, b.nonce, b.prev_hash, b.merkle_tree_root, b.difficulty, b.address)
    end

    def initialize(
      @index : Int64,
      @transactions : Array(Transaction),
      @nonce : String,
      @prev_hash : String,
      @merkle_tree_root : String,
      @difficulty : Int32,
      @address : String
    )
    end

    include NonceModels
  end
end
