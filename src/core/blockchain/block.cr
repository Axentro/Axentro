module ::Sushi::Core
  class Block
    extend Hashes

    JSON.mapping({
                   index: Int64,
                   transactions: Array(Transaction),
                   nonce: UInt64,
                   prev_hash: String,
                   merkle_tree_root: String,
                 })

    def initialize(
          @index : Int64,
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

    def to_header : Models::Header
      {
        index: @index,
        nonce: @nonce,
        prev_hash: @prev_hash,
        merkle_tree_root: @merkle_tree_root,
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

    def valid_nonce?(nonce : UInt64, difficulty = DIFFICULTY) : Bool
      valid?(self.to_hash, nonce, difficulty)
    end

    def valid_as_latest?(blockchain : Blockchain) : Bool
      is_genesis = (@index == 0)

      unless is_genesis
        raise "Invalid index, #{@index} have to be #{blockchain.chain.size}" if @index != blockchain.chain.size

        prev_block = blockchain.chain[-1]
        return valid_for?(prev_block)
      else
        raise "Index have to be '0' for genesis block: #{@index}" if @index != 0
        raise "Transaction have to be empty for genesis block: #{@transactions}" if !@transactions.empty?
        raise "nonce have to be '0' for genesis block: #{@nonce}" if @nonce != 0
        raise "prev_hash have to be 'genesis' for genesis block: #{@prev_hash}" if @prev_hash != "genesis"
      end

      transactions.each_with_index do |transaction, idx|
        return false unless transaction.valid?(blockchain, @index, idx == 0)
      end

      true
    end

    def valid_for?(prev_block : Block) : Bool
      raise "Mismatch index for the prev block(#{prev_block.index}): #{@index}" if prev_block.index + 1 != @index
      raise "prev_hash is invalid: #{prev_block.to_hash} != #{@prev_hash}" if prev_block.to_hash != @prev_hash
      raise "The nonce is invalid: #{@nonce}" if !prev_block.valid_nonce?(@nonce)

      merkle_tree_root = calcluate_merkle_tree_root
      raise "Invalid merkle tree root: #{merkle_tree_root} != #{@merkle_tree_root}" if merkle_tree_root != @merkle_tree_root

      true
    end

    def calculate_utxo : NamedTuple(utxo: Hash(String, Float64), indices: Hash(String, Int64))
      coinbase_address = @transactions.size > 0 ? @transactions[0].recipients[0][:address] : ""

      utxo = Hash(String, Float64).new
      utxo[coinbase_address] ||= 0.0 if coinbase_address.size > 0

      indices = Hash(String, Int64).new

      @transactions.each_with_index do |transaction, i|
        transaction.calculate_utxo.each do |address, amount|
          utxo[address] ||= 0.0
          utxo[address] = prec(utxo[address] + amount)
        end

        if coinbase_address.size > 0 && i > 0
          utxo[coinbase_address] = prec(utxo[coinbase_address] + transaction.calculate_fee)
        end

        indices[transaction.id] = @index
      end

      { utxo: utxo, indices: indices }
    end

    def find_transaction(transaction_id : String) : Transaction?
      @transactions.find { |t| t.id == transaction_id }
    end

    include Hashes
    include Consensus
    include Common::Num
  end
end
