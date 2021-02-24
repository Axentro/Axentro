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
  class FastBlock
    extend Hashes

    include JSON::Serializable
    property index : Int64
    property transactions : Array(Transaction)
    property prev_hash : String
    property merkle_tree_root : String
    property timestamp : Int64
    property kind : BlockKind
    property address : String
    property public_key : String
    property signature : String
    property hash : String
    property version : String

    def initialize(
      @index : Int64,
      @transactions : Array(Transaction),
      @prev_hash : String,
      @timestamp : Int64,
      @address : String,
      @public_key : String,
      @signature : String,
      @hash : String,
      @version : String
    )
      raise "index must be odd number" if index.even?
      @merkle_tree_root = calculate_merkle_tree_root
      @kind = BlockKind::FAST
      debug "fast: merkle tree root of minted block: #{@merkle_tree_root}"
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
      string = FastBlockNoTimestamp.from_fast_block(self).to_json
      sha256(string)
    end

    def self.to_hash(index : Int64, transactions : Array(Transaction), prev_hash : String, address : String, public_key : String) : String
      string = {index: index, transactions: transactions, prev_hash: prev_hash, address: address, public_key: public_key}.to_json
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
      is_fast_block? ? "FAST" : "SLOW"
    end

    private def validate_transactions(transactions : Array(Transaction), blockchain : Blockchain) : ValidatedTransactions
      result = FastTransactionPool.find_all(transactions)
      fast_transactions = result.found + result.not_found

      vt = Validation::Transaction.validate_common(fast_transactions, blockchain.network_type)

      coinbase_transactions = vt.passed.select(&.is_coinbase?)
      body_transactions = vt.passed.reject(&.is_coinbase?)

      vt.concat(Validation::Transaction.validate_coinbase(coinbase_transactions, body_transactions, blockchain, @index))
      vt.concat(Validation::Transaction.validate_embedded(coinbase_transactions + body_transactions, blockchain))
      vt
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def valid?(blockchain : Blockchain, skip_transactions : Bool = false, doing_replace : Bool = true) : Bool
      return true if @index <= 1_i64

      chain_network = blockchain.database.chain_network_kind
      block_network = Address.get_network_from_address(@address)

      if chain_network && block_network != chain_network
        raise "Invalid fast block network type: incoming block is of type: #{block_network[:name]} but chain is of type: #{chain_network.not_nil![:name]}"
      end

      valid_signature = KeyUtils.verify_signature(@hash, @signature, @public_key)
      raise "Invalid Block Signature: the current block index: #{@index} has an invalid signature" unless valid_signature

      prev_block_index = @index - 2
      _prev_block = blockchain.database.get_block(prev_block_index)

      raise "(fast_block::valid?) error finding fast previous block: #{prev_block_index} for current block: #{@index}" if _prev_block.nil?
      prev_block = _prev_block.not_nil!.as(FastBlock)

      raise "Invalid Previous Fast Block Hash: for current index: #{@index} the fast block prev_hash is invalid: (prev index: #{prev_block.index}) #{prev_block.to_hash} != #{@prev_hash}" if prev_block.to_hash != @prev_hash

      unless skip_transactions
        vt = validate_transactions(transactions, blockchain)
        raise vt.failed.first.reason if vt.failed.size != 0
      end

      # Add an extra 30 seconds for latency when running fastnode on it's own node
      next_timestamp = __timestamp + 30000
      prev_timestamp = prev_block.timestamp

      if prev_timestamp > @timestamp || next_timestamp < @timestamp
        raise "Fast Invalid Timestamp: #{@timestamp} " +
              "(timestamp should be bigger than #{prev_timestamp} and smaller than #{next_timestamp})"
      end

      merkle_tree_root = calculate_merkle_tree_root

      if merkle_tree_root != @merkle_tree_root
        raise "Fast Invalid Merkle Tree Root: (expected #{@merkle_tree_root} but got #{merkle_tree_root})"
      end

      unless doing_replace
        latest_fast_index = blockchain.get_latest_index_for_fast
        raise "Fast Index Mismatch: the current block index: #{@index} should match the lastest fast block index: #{latest_fast_index}" if @index != latest_fast_index
      end

      true
    end

    def valid_as_genesis? : Bool
      false
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
  end

  class FastBlockNoTimestamp
    include JSON::Serializable
    property index : Int64
    property transactions : Array(Transaction)
    property prev_hash : String
    property merkle_tree_root : String
    property address : String
    property public_key : String
    property signature : String
    property hash : String

    def self.from_fast_block(b : FastBlock)
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
  end
end
