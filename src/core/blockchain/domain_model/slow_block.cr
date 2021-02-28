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
    property public_key : String
    property signature : String
    property hash : String
    property version : String

    def initialize(
      @index : Int64,
      @transactions : Array(Transaction),
      @nonce : BlockNonce,
      @prev_hash : String,
      @timestamp : Int64,
      @difficulty : Int32,
      @kind : BlockKind,
      @address : String,
      @public_key : String,
      @signature : String,
      @hash : String,
      @version : String
    )
      if @kind == BlockKind::SLOW && index.odd?
        raise AxentroException.new("index must be even number")
      end
      if @kind == BlockKind::FAST && index.even?
        raise AxentroException.new("index must be odd number")
      end

      @merkle_tree_root = calculate_merkle_tree_root(@transactions)
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

    def to_hash : String
      string = SlowBlockNoTimestamp.from_slow_block(self).to_json
      sha256(string)
    end

    # for fast block
    def self.to_hash(index : Int64, transactions : Array(Transaction), prev_hash : String, address : String, public_key : String) : String
      string = {index: index, transactions: transactions, prev_hash: prev_hash, address: address, public_key: public_key}.to_json
      sha256(string)
    end

    def calculate_merkle_tree_root(transactions : Array(Transaction)) : String
      return "" if transactions.size == 0

      current_hashes = transactions.map { |tx| tx.to_hash }

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

    # This uses the @ shortcut to set the nonce onto the block
    def with_nonce(@nonce : BlockNonce) : SlowBlock
      self
    end

    def with_difficulty(@difficulty : Int32) : SlowBlock
      self
    end

    def with_timestamp(@timestamp : Int64) : SlowBlock
      self
    end

    def valid_block_nonce?(difficulty : Int32) : Bool
      is_nonce_valid?(to_hash, @nonce, difficulty)
    end

    def valid?(blockchain : Blockchain, skip_transactions : Bool = false, doing_replace : Bool = false) : Bool
      # if @kind == BlockKind::FAST
      #   return true if @index <= 1_i64
      #   validated_block = BlockValidator.validate_fast(self.as(FastBlock), blockchain, skip_transactions, doing_replace)
      #   validated_block.valid ? validated_block.valid : raise Axentro::Common::AxentroException.new(validated_block.reason)
      # else
      #   validated_block = BlockValidator.validate_slow(self.as(SlowBlock), blockchain, skip_transactions, doing_replace)
      #   validated_block.valid ? validated_block.valid : raise Axentro::Common::AxentroException.new(validated_block.reason)
      # end
      true
    end

    def find_transaction(transaction_id : String) : Transaction?
      @transactions.find { |t| t.id.starts_with?(transaction_id) }
    end

    def set_transactions(txns : Transactions)
      @transactions = txns
      verbose "Number of transactions in block: #{txns.size}"
      @merkle_tree_root = calculate_merkle_tree_root(@transactions)
    end

    include Hashes
    include Logger
    include Protocol
    include Consensus
    include Common
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
    property public_key : String
    property signature : String
    property hash : String
    property version : String

    def self.from_slow_block(b : SlowBlock)
      SlowBlockNoTimestamp.new(b.index, b.transactions, b.nonce, b.prev_hash, b.merkle_tree_root, b.difficulty, b.address, b.public_key, b.signature, b.hash, b.version)
    end

    def initialize(
      @index : Int64,
      @transactions : Array(Transaction),
      @nonce : String,
      @prev_hash : String,
      @merkle_tree_root : String,
      @difficulty : Int32,
      @address : String,
      @public_key : String,
      @signature : String,
      @hash : String,
      @version : String
    )
    end

    include NonceModels
  end
end
