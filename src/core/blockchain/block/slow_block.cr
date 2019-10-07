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

module ::Sushi::Core
  class SlowBlock
    extend Hashes

    JSON.mapping({
      index:            Int64,
      transactions:     Array(Transaction),
      nonce:            UInt64,
      prev_hash:        String,
      merkle_tree_root: String,
      timestamp:        Int64,
      difficulty:       Int32,
      kind:             BlockKind,
      address:          String,
    })

    def initialize(
      @index : Int64,
      @transactions : Array(Transaction),
      @nonce : UInt64,
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
      debug "SlowBlock transactions: #{@transactions.size}"
      debug "SlowBlock nonce: #{@nonce}"
      debug "SlowBlock prev_hash: #{@prev_hash}"
      debug "SlowBlock timestamp: #{@timestamp}"
      debug "SlowBlock difficulty: #{@difficulty}"
      debug "SlowBlock hash: #{self.to_hash}"
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

        (current_hashes.size / 2).times do |i|
          tmp_hashes.push(sha256(current_hashes[i*2] + current_hashes[i*2 + 1]))
        end

        tmp_hashes.push(current_hashes[-1]) if current_hashes.size % 2 == 1

        current_hashes = tmp_hashes
        break if current_hashes.size == 1
      end

      ripemd160(current_hashes[0])
    end

    def valid?(blockchain : Blockchain, skip_transactions : Bool = false) : Bool
      return valid_as_latest?(blockchain, skip_transactions) unless @index == 0
      valid_as_genesis?
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

    def with_nonce(@nonce : UInt64) : SlowBlock
      self
    end

    def valid_nonce?(difficulty : Int32)
      valid_nonce?(self.to_hash, @nonce, difficulty)
    end

    def valid?(blockchain : Blockchain, skip_transactions : Bool = false) : Bool
      return valid_as_latest?(blockchain, skip_transactions) unless @index == 0
      valid_as_genesis?
    end

    private def process_transaction(blockchain, transaction, idx)
      t = SlowTransactionPool.find(transaction) || transaction
      t.valid_common?

      if idx == 0
        t.valid_as_coinbase?(blockchain, @index, transactions[1..-1])
      else
        t.valid_as_embedded?(blockchain, transactions[0..idx - 1])
      end
    end

    def valid_as_latest?(blockchain : Blockchain, skip_transactions : Bool) : Bool
      prev_block = blockchain.latest_slow_block
      latest_slow_index = blockchain.get_latest_index_for_slow

      unless skip_transactions
        transactions.each_with_index do |t, idx|
          process_transaction(blockchain, t, idx)
        end
      end

      raise "Index Mismatch: the current block index: #{@index} should match the lastest slow block index: #{latest_slow_index}" if @index != latest_slow_index
      raise "Invalid Previous Hash: for current index: #{@index} the prev_hash is invalid: (prev index: #{prev_block.index}) #{prev_block.to_hash} != #{@prev_hash}" if prev_block.to_hash != @prev_hash

      next_timestamp = __timestamp
      prev_timestamp = prev_block.timestamp

      if prev_timestamp > @timestamp || next_timestamp < @timestamp
        raise "Invalid Timestamp: #{@timestamp} " +
              "(timestamp should be bigger than #{prev_timestamp} and smaller than #{next_timestamp})"
      end

      difficulty_for_block = block_difficulty(blockchain)
      debug "Calculated a difficulty of #{difficulty_for_block} for block #{@index} in validity check"
      difficulty_for_block = prev_block.index == 0 ? @difficulty : difficulty_for_block

      if @difficulty > 0
        if @difficulty != difficulty_for_block
          raise "Invalid difficulty: " + "(expected #{difficulty_for_block} but got #{@difficulty})"
        end
        raise "Invalid Nonce: #{@nonce} for difficulty #{@difficulty}" unless self.valid_nonce?(@difficulty) >= block_difficulty_to_miner_difficulty(@difficulty)
      end

      merkle_tree_root = calculate_merkle_tree_root

      if merkle_tree_root != @merkle_tree_root
        raise "Invalid Merkle Tree Root: (expected #{@merkle_tree_root} but got #{merkle_tree_root})"
      end

      true
    end

    def valid_as_genesis? : Bool
      raise "Invalid Genesis Index: index has to be '0' for genesis block: #{@index}" if @index != 0
      raise "Invalid Genesis Nonce: nonce has to be '0' for genesis block: #{@nonce}" if @nonce != 0
      raise "Invalid Genesis Previous Hash: prev_hash has to be 'genesis' for genesis block: #{@prev_hash}" if @prev_hash != "genesis"
      raise "Invalid Genesis Difficulty: difficulty has to be '#{Consensus::DEFAULT_DIFFICULTY_TARGET}' for genesis block: #{@difficulty}" if @difficulty != Consensus::DEFAULT_DIFFICULTY_TARGET
      raise "Invalid Genesis Address: address has to be 'genesis' for genesis block" if @address != "genesis"
      true
    end

    def find_transaction(transaction_id : String) : Transaction?
      @transactions.find { |t| t.id == transaction_id }
    end

    def set_transactions(txns : Transactions)
      @transactions = txns
      debug "Number of transactions in block: #{txns.size}"
      @merkle_tree_root = calculate_merkle_tree_root
    end

    include Block
    include Hashes
    include Logger
    include Protocol
    include Consensus
    include Common::Timestamp
  end

  class SlowBlockNoTimestamp
    JSON.mapping({
      index:            Int64,
      transactions:     Array(Transaction),
      nonce:            UInt64,
      prev_hash:        String,
      merkle_tree_root: String,
      difficulty:       Int32,
      address:          String,
    })

    def self.from_slow_block(b : SlowBlock)
      SlowBlockNoTimestamp.new(b.index, b.transactions, b.nonce, b.prev_hash, b.merkle_tree_root, b.difficulty, b.address)
    end

    def initialize(
      @index : Int64,
      @transactions : Array(Transaction),
      @nonce : UInt64,
      @prev_hash : String,
      @merkle_tree_root : String,
      @difficulty : Int32,
      @address : String
    )
    end
  end
end
