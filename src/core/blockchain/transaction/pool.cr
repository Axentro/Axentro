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
  class TransactionPool
    @@worker : TransactionPool? = nil

    @pool : Transactions = Transactions.new
    @pool_locked : Transactions = Transactions.new

    @locked : Bool = false

    alias TxPoolWork = NamedTuple(call: Int32, content: String)

    def self.setup
      @@worker ||= TransactionPool.new
    end

    def self.worker : TransactionPool
      @@worker.not_nil!
    end

    def self.add(transaction : Transaction)
      worker.add(transaction)
    end

    def add(transaction : Transaction)
      if @locked
        @pool_locked << transaction
      else
        @pool << transaction
      end
    end

    def self.delete(transaction : Transaction)
      worker.delete(transaction)
    end

    def delete(transaction : Transaction)
      @pool.reject! { |t| t.id == transaction.id }
    end

    def self.replace(transactions : Transactions)
      worker.replace(transactions)
    end

    def replace(transactions : Transactions)
      @pool = transactions
      @pool.concat(@pool_locked)

      @locked = false

      @pool_locked.clear
    end

    def self.all
      worker.all
    end

    def all
      @pool
    end

    def self.align(coinbase_transaction : Transaction, coinbase_amount : Int64)
      worker.align(coinbase_transaction, coinbase_amount)
    end

    def align(coinbase_transaction : Transaction, coinbase_amount : Int64)
      aligned_transactions = [coinbase_transaction]

      rejects = [] of NamedTuple(transaction_id: String, reason: String)

      @pool.each do |t|
        t.prev_hash = aligned_transactions[-1].to_hash
        t.valid_without_dapps?(coinbase_amount, aligned_transactions)

        aligned_transactions << t
      rescue e : Exception
        rejects << {transaction_id: t.id, reason: e.message || "unknown"}
      end

      {
        transactions: aligned_transactions,
        rejects:      rejects,
      }
    end

    def self.validate(coinbase_amount : Int64, transactions : Transactions)
      worker.validate(coinbase_amount, transactions)
    end

    def validate(coinbase_amount : Int64, transactions : Transactions)
      transactions.each_with_index do |t, idx|
        t.valid_without_dapps?(coinbase_amount, idx == 0 ? [] of Transaction : transactions[0..idx - 1])
      rescue e : Exception
        return {valid: false, reason: e.message.not_nil!}
      end

      {valid: true, reason: ""}
    end

    def self.lock
      worker.lock
    end

    def lock
      @locked = true
    end

    include Logger
    include TransactionModels
  end
end
