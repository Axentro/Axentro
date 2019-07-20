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
  class Block
    extend Hashes

    JSON.mapping({
      index:            Int64,
      transactions:     Array(Transaction),
      nonce:            UInt64,
      prev_hash:        String,
      merkle_tree_root: String,
      timestamp:        Int64,
      difficulty:  Int32,
    })

    def initialize(
      @index : Int64,
      @transactions : Array(Transaction),
      @nonce : UInt64,
      @prev_hash : String,
      @timestamp : Int64,
      @difficulty : Int32
    )
      @merkle_tree_root = calculate_merkle_tree_root
    end

    def to_hash : String
      string = self.to_json
      sha256(string)
    end

    def to_s
      debug "Block index: #{@index}"
      debug "Block transactions: #{@transactions.size}"
      debug "Block nonce: #{@nonce}"
      debug "Block prev_hash: #{@prev_hash}"
      debug "Block timestamp: #{@timestamp}"
      debug "Block difficulty: #{@difficulty}"
      debug "Block hash: #{self.to_hash}"
    end

    def to_header : Blockchain::Header
      {
        index:            @index,
        nonce:            @nonce,
        prev_hash:        @prev_hash,
        merkle_tree_root: @merkle_tree_root,
        timestamp:        @timestamp,
        difficulty:       @difficulty,
      }
    end

    def with_nonce(@nonce : UInt64) : Block
      self
    end

    def with_timestamp(@timestamp : Int64) : Block
      self
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

    def valid_nonce?(difficulty : Int32)
      valid_nonce?(self.to_hash, @nonce, difficulty)
    end

    def valid?(blockchain : Blockchain, skip_transactions : Bool = false) : Bool
      return valid_as_latest?(blockchain, skip_transactions) unless @index == 0
      valid_as_genesis?
    end

    def validate_transactions(blockchain : Blockchain, transactions : Array(Transaction))
      transactions.each_with_index do |t, idx|
        t = TransactionPool.find(t) || t
        t.valid_common?

        if idx == 0
          t.valid_as_coinbase?(blockchain, @index, transactions[1..-1])
        else
          t.valid_as_embedded?(blockchain, transactions[0..idx - 1])
        end
      end
    end

    def valid_as_latest?(blockchain : Blockchain, skip_transactions : Bool) : Bool
      prev_block = blockchain.latest_block

      raise "invalid index, #{@index} have to be #{blockchain.chain.size}" if @index != blockchain.chain.size
      debug "in valid_as_latest?.. using difficulty: #{@difficulty}"
      validate_transactions(blockchain, transactions) unless skip_transactions

      raise "mismatch index for the most recent block(#{prev_block.index}): #{@index}" if prev_block.index + 1 != @index
      raise "prev_hash is invalid: #{prev_block.to_hash} != #{@prev_hash}" if prev_block.to_hash != @prev_hash

      next_timestamp = __timestamp
      prev_timestamp = prev_block.timestamp

      if prev_timestamp > @timestamp || next_timestamp < @timestamp
        raise "timestamp is invalid: #{@timestamp} " +
              "(timestamp should be bigger than #{prev_timestamp} and smaller than #{next_timestamp})"
      end

      difficulty_for_block = block_difficulty(blockchain)
      debug "Calculated a difficulty of #{difficulty_for_block} in validity check"
      difficulty_for_block = prev_block.index == 0 ? @difficulty : difficulty_for_block

      if @difficulty > 0
        if @difficulty != difficulty_for_block
          raise "difficulty is invalid " + "(expected #{difficulty_for_block} but got #{@difficulty})"
        end
        raise "the nonce is invalid: #{@nonce} for difficulty #{@difficulty}" unless self.valid_nonce?(@difficulty) >= block_difficulty_to_miner_difficulty(@difficulty)
      end

      merkle_tree_root = calculate_merkle_tree_root

      if merkle_tree_root != @merkle_tree_root
        raise "invalid merkle tree root (expected #{@merkle_tree_root} but got #{merkle_tree_root})"
      end

      true
    end

    def valid_as_genesis? : Bool
      raise "index has to be '0' for genesis block: #{@index}" if @index != 0
      raise "transactions have to be empty for genesis block: #{@transactions}" if !@transactions.empty?
      raise "nonce has to be '0' for genesis block: #{@nonce}" if @nonce != 0
      raise "prev_hash has to be 'genesis' for genesis block: #{@prev_hash}" if @prev_hash != "genesis"
      raise "difficulty has to be '#{Consensus::DEFAULT_DIFFICULTY_TARGET}' for genesis block: #{@difficulty}" if @difficulty != Consensus::DEFAULT_DIFFICULTY_TARGET

      true
    end

    def find_transaction(transaction_id : String) : Transaction?
      @transactions.find { |t| t.id == transaction_id }
    end

    include Hashes
    include Logger
    include Protocol
    include Consensus
    include Common::Timestamp
  end
end
