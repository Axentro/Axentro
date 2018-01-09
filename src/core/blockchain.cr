require "./blockchain/*"

module ::Garnet::Core
  class Blockchain
    getter chain : Models::Chain = Models::Chain.new
    getter current_transactions = [] of Transaction
    getter wallet : Wallet
    getter utxo : UTXO

    def initialize(@wallet : Wallet)
      @utxo = UTXO.new
      @chain.push(genesis_block)

      add_transaction(create_first_transaction)
    end

    def push_block?(nonce : UInt64) : Block?
      return nil unless last_block.valid_nonce?(nonce)

      index = @chain.size.to_u32
      transactions = @current_transactions.dup

      block = Block.new(
        index,
        transactions,
        nonce,
        last_block.to_hash,
      )

      push_block?(block)
    end

    def push_block?(block : Block) : Block?
      return nil unless block.valid_as_last?(self)

      @chain.push(block)
      record_utxo

      @current_transactions.clear
      add_transaction(create_first_transaction)

      block
    end

    def replace_chain(subchain : Models::Chain) : Bool
      return false if subchain.size == 0
      return false if subchain[0].index == 0

      first_index = subchain[0].index-1
      prev_block = @chain[first_index]

      subchain.each do |block|
        return false unless block.valid_for?(prev_block)

        prev_block = block
      end

      @utxo.cut(first_index)
      @chain = @chain[0..first_index].concat(subchain)

      record_utxo

      true
    end

    def add_transaction(transaction : Transaction)
      transaction.prev_hash = if @current_transactions.size == 0
                                "0"
                              else
                                @current_transactions[-1].to_hash
                              end

      @current_transactions.push(transaction)
    end

    def get_amount_unconfirmed(address : String) : Float64
      @utxo.get_unconfirmed(address)
    end

    def get_amount(address : String) : Float64
      @utxo.get(address)
    end

    def last_block : Block
      @chain[-1]
    end

    def last_index : UInt32
      last_block.index
    end

    def subchain(from : UInt32)
      return nil if @chain.size < from

      @chain[from..-1]
    end

    def record_utxo
      @utxo.record(@chain)
    end

    def genesis_block : Block
      genesis_index = 0_u32
      genesis_transactions = [] of Transaction
      genesis_nonce = 0_u64
      genesis_prev_hash = "genesis"

      Block.new(
        genesis_index,
        genesis_transactions,
        genesis_nonce,
        genesis_prev_hash,
      )
    end

    def create_first_transaction : Transaction
      Transaction.new(
        Transaction.create_id,
        "head",
        [] of Models::Sender, # No senders
              [
                {
                  address: @wallet.address,
                  amount: Blockchain.served_amount(last_index),
                },
              ],
              "0", # prev_hash
              "0", # sign_r
              "0", # sign_s
      )
    end

    def create_unsigned_transaction(action, senders, recipients) : Transaction
      Transaction.new(
        Transaction.create_id,
        action,
        senders,
        recipients,
        "0", # prev_hash
        "0", # sign_r
        "0", # sign_s
      )
    end

    def self.served_amount(index)
      10.0
    end

    include Hashes
  end
end
