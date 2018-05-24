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
      difficulty:       Int32,
    })

    def initialize(
      @index : Int64,
      @transactions : Array(Transaction),
      @nonce : UInt64,
      @prev_hash : String,
      @timestamp : Int64,
      @difficulty : Int32
    )
      @merkle_tree_root = calcluate_merkle_tree_root
    end

    def to_hash : String
      string = self.to_json
      sha256(string)
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

    def calcluate_merkle_tree_root : String
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

    def valid_nonce?(nonce : UInt64, difficulty : Int32? = nil) : Bool
      valid?(self.index, self.to_hash, nonce, difficulty)
    end

    def valid_as_latest?(blockchain : Blockchain, skip_transaction_validation : Bool = false) : Bool
      is_genesis = (@index == 0)

      unless is_genesis
        raise "invalid index, #{@index} have to be #{blockchain.chain.size}" if @index != blockchain.chain.size

        unless skip_transaction_validation
          transactions.each_with_index do |transaction, idx|
            transaction.valid?(blockchain, idx == 0 ? [] of Transaction : transactions[0..idx - 1])
          end
        end

        return valid_for?(blockchain.latest_block)
      else
        raise "index has to be '0' for genesis block: #{@index}" if @index != 0
        raise "transactions have to be empty for genesis block: #{@transactions}" if !@transactions.empty?
        raise "nonce has to be '0' for genesis block: #{@nonce}" if @nonce != 0
        raise "prev_hash has to be 'genesis' for genesis block: #{@prev_hash}" if @prev_hash != "genesis"
      end

      true
    end

    def valid_for?(prev_block : Block) : Bool
      raise "mismatch index for the prev block(#{prev_block.index}): #{@index}" if prev_block.index + 1 != @index
      raise "prev_hash is invalid: #{prev_block.to_hash} != #{@prev_hash}" if prev_block.to_hash != @prev_hash
      raise "the nonce is invalid: #{@nonce}" if !prev_block.valid_nonce?(@nonce)

      next_timestamp = timestamp
      prev_timestamp = prev_block.timestamp

      if prev_timestamp > @timestamp || next_timestamp < @timestamp
        raise "timestamp is invalid: #{@timestamp} (timestamp should be bigger than #{prev_timestamp} and smaller than #{next_timestamp})"
      end

      merkle_tree_root = calcluate_merkle_tree_root
      raise "invalid merkle tree root: #{merkle_tree_root} != #{@merkle_tree_root}" if merkle_tree_root != @merkle_tree_root

      true
    end

    def find_transaction(transaction_id : String) : Transaction?
      @transactions.find { |t| t.id == transaction_id }
    end

    def total_fees : Int64
      return 0_i64 if @transactions.size < 2
      @transactions[1..-1].reduce(0_i64) { |fees, transaction| fees + transaction.total_fees }
    end

    #
    # y : coinbase amount
    # x : index
    # r : radius
    #
    # Aim to be the total coinbase amount: 20000000 [SUSHI]
    #
    # y = sqrt(r^2 - x^2)
    #
    # (r * r * PI) / 4 == 100000000000000
    # => r = sqrt(8000000000000000 / PI)
    # => r = 50462650.4404032
    # => r ^ 2 = 2546479089470325
    #
    # < result >
    # Total amount : 20000000.00004112 [SUSHI]
    # Last index   : 50462651
    #
    RR = 2546479089470325

    def coinbase_amount : Int64
      index_index = @index * @index

      return total_fees if index_index > RR

      Math.sqrt(RR - index_index).to_i64
    end

    include Hashes
    include Consensus
    include Common::Timestamp
  end
end
