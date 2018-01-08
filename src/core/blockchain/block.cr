module ::Garnet::Core
  class Block
    extend Hashes

    DIFFICULTY = 5

    JSON.mapping({
                   index: UInt32,
                   transactions: Array(Transaction),
                   nonce: UInt64,
                   prev_hash: String,
                   merkle_tree_root: String,
                 })

    getter index

    def initialize(
          @index : UInt32,
          @transactions : Array(Transaction),
          @nonce : UInt64,
          @prev_hash : String,
        )
      @merkle_tree_root = calcluate_merkle_tree_root
    end

    def to_hash : String
      string = self.to_json
      sha256(string)
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

    def self.valid_nonce?(block_hash : String, nonce : UInt64) : Bool
      guess_nonce = "#{block_hash}#{nonce}"
      guess_hash = sha256(guess_nonce)
      guess_hash[0, DIFFICULTY] == "0" * DIFFICULTY
    end

    def valid_nonce?(nonce : UInt64) : Bool
      Block.valid_nonce?(self.to_hash, nonce)
    end

    def valid_as_last?(blockchain : Blockchain) : Bool
      is_genesis = (@index == 0)

      unless is_genesis
        return false if @index != blockchain.chain.size

        prev_block = blockchain.chain[-1]
        return valid_for?(prev_block)
      else
        return false if @index != 0
        return false if !@transactions.empty?
        return false if @nonce != 0
        return false if @prev_hash != "genesis"
      end

      transactions.each_with_index do |transaction, idx|
        return false unless transaction.valid?(blockchain, @index, idx == 0)
      end

      true
    end

    def valid_for?(prev_block : Block) : Bool
      return false if prev_block.index + 1 != @index
      return false if prev_block.to_hash != @prev_hash
      return false if !prev_block.valid_nonce?(@nonce)

      merkle_tree_root = calcluate_merkle_tree_root
      return false if merkle_tree_root != @merkle_tree_root

      true
    end

    def calculate_utxo : Hash(String, Float64)
      coinbase_address = @transactions.size > 0 ? @transactions[0].recipients[0][:address] : ""

      utxo = Hash(String, Float64).new
      utxo[coinbase_address] ||= 0.0 if coinbase_address.size > 0

      @transactions.each_with_index do |transaction, i|
        transaction.calculate_utxo.each do |address, amount|
          utxo[address] ||= 0.0
          utxo[address] = prec(utxo[address] + amount)
        end

        if coinbase_address.size > 0 && i > 0
          utxo[coinbase_address] = prec(utxo[coinbase_address] + transaction.calculate_fee)
        end
      end

      utxo
    end

    include Hashes
    include Common::Num
  end
end
