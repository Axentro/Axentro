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
  alias Chain = Array(Block)

  enum BlockKind
    SLOW
    FAST

    def to_json(j : JSON::Builder)
      j.string(to_s)
    end
  end

  class Block
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
    property hash_version : String

    # full
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
      @version : String,
      @hash_version : String,
      @merkle_tree_root : String
    )
    end

    # slow
    def initialize(
      @index : Int64,
      @transactions : Array(Transaction),
      @nonce : BlockNonce,
      @prev_hash : String,
      @timestamp : Int64,
      @difficulty : Int32,
      @address : String,
      @version : String,
      @hash_version : String
    )
      @public_key = ""
      @signature = ""
      @hash = ""
      @kind = BlockKind::SLOW
      if index.odd?
        raise AxentroException.new("index must be even number")
      end

      @merkle_tree_root = calculate_merkle_tree_root(@transactions)
    end

    # fast
    def initialize(
      @index : Int64,
      @transactions : Array(Transaction),
      @prev_hash : String,
      @timestamp : Int64,
      @address : String,
      @public_key : String,
      @signature : String,
      @hash : String,
      @version : String,
      @hash_version : String
    )
      @nonce = ""
      @difficulty = 0
      @kind = BlockKind::FAST

      if index.even?
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
      if @version == Core::BLOCK_VERSION
        string = SlowBlockNoTimestampV2.from_block(self).to_json
        argon2(string)
      else
        if @kind == BlockKind::FAST
          string = FastBlockNoTimestampV1.from_fast_block(self).to_json
          sha256(string)
        else
          string = SlowBlockNoTimestampV1.from_slow_block(self).to_json
          sha256(string)
        end
      end
    end

    # for fast block
    def self.to_hash(index : Int64, transactions : Array(Transaction), prev_hash : String, address : String, public_key : String) : String
      string = {index: index, transactions: transactions, prev_hash: prev_hash, address: address, public_key: public_key}.to_json
      sha256(string)
    end

    def calculate_merkle_tree_root(transactions : Array(Transaction)) : String
      MerkleTreeCalculator.new(@hash_version).calculate_merkle_tree_root(transactions)
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
    def with_nonce(@nonce : BlockNonce) : Block
      self
    end

    def with_difficulty(@difficulty : Int32) : Block
      self
    end

    def with_timestamp(@timestamp : Int64) : Block
      self
    end

    def valid_block_nonce?(difficulty : Int32) : Bool
      is_nonce_valid?(to_hash, @nonce, difficulty)
    end

    def valid?(blockchain : Blockchain, skip_transactions : Bool = false, doing_replace : Bool = false) : Bool
      if @kind == BlockKind::FAST
        return true if @index <= 1_i64
        validated_block = BlockValidator.validate_fast(self, blockchain, skip_transactions, doing_replace)
        validated_block.valid ? validated_block.valid : raise Axentro::Common::AxentroException.new(validated_block.reason)
      else
        validated_block = BlockValidator.validate_slow(self, blockchain, skip_transactions, doing_replace)
        validated_block.valid ? validated_block.valid : raise Axentro::Common::AxentroException.new(validated_block.reason)
      end
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

  class SlowBlockNoTimestampV1
    include JSON::Serializable
    property index : Int64
    property transactions : Array(Transaction)
    property nonce : String
    property prev_hash : String
    property merkle_tree_root : String
    property difficulty : Int32
    property address : String

    def self.from_slow_block(b : Block)
      self.new(b.index, b.transactions, b.nonce, b.prev_hash, b.merkle_tree_root, b.difficulty, b.address)
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

    def to_json(j : JSON::Builder)
      j.object do
        j.field("index", @index)
        j.field("nonce", @nonce)
        j.field("prev_hash", @prev_hash)
        j.field("merkle_tree_root", @merkle_tree_root)
        j.field("difficulty", @difficulty)
        j.field("address", @address)
        j.field("transactions", @transactions.to_json)
      end
    end

    include NonceModels
  end

  class FastBlockNoTimestampV1
    include JSON::Serializable
    property index : Int64
    property transactions : Array(Transaction)
    property prev_hash : String
    property merkle_tree_root : String
    property address : String
    property public_key : String
    property signature : String
    property hash : String

    def self.from_fast_block(b : Block)
      self.new(b.index, b.transactions, b.prev_hash, b.merkle_tree_root, b.address, b.public_key, b.signature, b.hash)
    end

    def initialize(
      @index : Int64,
      @transactions : Array(Transaction),
      @prev_hash : String,
      @merkle_tree_root : String,
      @address : String,
      @public_key : String,
      @signature : String,
      @hash : String
    )
    end

    # def to_json
    #   JSON.build do |json|
    #     json.object do
    #       json.field("index", @index)
    #       json.field("prev_hash", @prev_hash)
    #       json.field("merkle_tree_root", @merkle_tree_root)
    #       json.field("address", @address)
    #       json.field("public_key", @public_key)
    #       json.field("signature", @signature)
    #       json.field("hash", @hash)
    #       json.field("transactions", @transactions.to_json)
    #     end
    #   end
    # end
  end

  class SlowBlockNoTimestampV2
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
    property hash_version : String

    def self.from_block(b : Block)
      self.new(b.index, b.transactions, b.nonce, b.prev_hash, b.merkle_tree_root, b.difficulty, b.address, b.public_key, b.signature, b.hash, b.version, b.hash_version)
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
      @version : String,
      @hash_version : String
    )
    end

    def to_json(j : JSON::Builder)
      j.object do
        j.field("index", @index)
        j.field("nonce", @nonce)
        j.field("prev_hash", @prev_hash)
        j.field("merkle_tree_root", @merkle_tree_root)
        j.field("difficulty", @difficulty)
        j.field("address", @address)
        j.field("public_key", @public_key)
        j.field("signature", @signature)
        j.field("hash", @hash)
        j.field("version", @version)
        j.field("hash_version", @hash_version)
        j.field("transactions", @transactions)
      end
    end

    include NonceModels
  end
end
