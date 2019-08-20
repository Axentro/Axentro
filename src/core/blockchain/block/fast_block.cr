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
  class FastBlock
extend Hashes

    JSON.mapping({
      index:            Int64,
      transactions:     Array(Transaction),
      prev_hash:        String,
      merkle_tree_root: String,
      timestamp:        Int64
    })

    def initialize(
      @index : Int64,
      @transactions : Array(Transaction),
      @prev_hash : String,
      @timestamp : Int64,
    )
      raise "index must be odd number" if index.even?
      @merkle_tree_root = calculate_merkle_tree_root
    end

    def to_header : Blockchain::FastHeader
      {
        index:            @index,
        prev_hash:        @prev_hash,
        merkle_tree_root: @merkle_tree_root,
        timestamp:        @timestamp,
      }
    end

    def to_hash : String
      string = self.to_json
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
      typeof(self) == SlowBlock
    end

    def is_fast_block?
      typeof(self) == FastBlock
    end

    def kind : String
      is_fast_block? ? "FAST" : "SLOW"
    end

    def valid?(blockchain : Blockchain, skip_transactions : Bool = false) : Bool
      return valid_as_latest?(blockchain, skip_transactions) unless @index == 0
      valid_as_genesis?
    end

    private def process_transaction(blockchain, transaction, idx)
      t = FastTransactionPool.find(transaction) || transaction
      t.valid_common?

      if idx == 0
        t.valid_as_coinbase?(blockchain, @index, transactions[1..-1])
      else
        t.valid_as_embedded?(blockchain, transactions[0..idx - 1])
      end
    end

    def valid_as_latest?(blockchain : Blockchain, skip_transactions : Bool) : Bool
      # TODO - fix this
      return true

      prev_block = blockchain.latest_block

      expected_chain_size = blockchain.chain.select(&.is_fast_block?).size
      p "FAST VALID: #{expected_chain_size}"
      raise "invalid index, #{@index} have to be #{expected_chain_size}" if @index != expected_chain_size
      # debug "in valid_as_latest?.. using difficulty: #{@difficulty}"

      unless skip_transactions
        transactions.each_with_index do |t, idx|
          process_transaction(blockchain, t, idx)
        end
      end

      raise "mismatch index for the most recent block(#{prev_block.index}): #{@index}" if prev_block.index + 1 != @index
      raise "prev_hash is invalid: #{prev_block.to_hash} != #{@prev_hash}" if prev_block.to_hash != @prev_hash

      next_timestamp = __timestamp
      prev_timestamp = prev_block.timestamp

      if prev_timestamp > @timestamp || next_timestamp < @timestamp
        raise "timestamp is invalid: #{@timestamp} " +
              "(timestamp should be bigger than #{prev_timestamp} and smaller than #{next_timestamp})"
      end

      # difficulty_for_block = block_difficulty(blockchain)
      # debug "Calculated a difficulty of #{difficulty_for_block} in validity check"
      # difficulty_for_block = prev_block.index == 0 ? @difficulty : difficulty_for_block
      #
      # if @difficulty > 0
      #   if @difficulty != difficulty_for_block
      #     raise "difficulty is invalid " + "(expected #{difficulty_for_block} but got #{@difficulty})"
      #   end
      #   raise "the nonce is invalid: #{@nonce} for difficulty #{@difficulty}" unless self.valid_nonce?(@difficulty) >= block_difficulty_to_miner_difficulty(@difficulty)
      # end

      merkle_tree_root = calculate_merkle_tree_root

      if merkle_tree_root != @merkle_tree_root
        raise "invalid merkle tree root (expected #{@merkle_tree_root} but got #{merkle_tree_root})"
      end

      true
    end

    def valid_as_genesis? : Bool
      false
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
