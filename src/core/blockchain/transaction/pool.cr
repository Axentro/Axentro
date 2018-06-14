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
    @@instance : TransactionPool? = nil

    @pool : Transactions = Transactions.new
    @pool_locked : Transactions = Transactions.new

    @locked : Bool = false

    alias TxPoolWork = NamedTuple(call: Int32, content: String)

    def self.setup
      @@instance ||= TransactionPool.new
    end

    def self.instance : TransactionPool
      @@instance.not_nil!
    end

    def self.add(transaction : Transaction)
      instance.add(transaction)
    end

    def add(transaction : Transaction)
      if @locked
        @pool_locked << transaction
      else
        @pool << transaction
      end
    end

    def self.delete(transaction : Transaction)
      instance.delete(transaction)
    end

    def delete(transaction : Transaction)
      @pool.reject! { |t| t.id == transaction.id }
    end

    def self.replace(transactions : Transactions)
      instance.replace(transactions)
    end

    def replace(transactions : Transactions)
      @pool = transactions
      @pool.concat(@pool_locked)

      @locked = false

      @pool_locked.clear
    end

    def self.all
      instance.all
    end

    def all
      @pool
    end

    def self.lock
      instance.lock
    end

    def lock
      @locked = true
    end

    def self.find(transaction : Transaction)
      instance.find(transaction)
    end

    def find(transaction : Transaction) : Transaction?
      return nil unless found_transaction = @pool.find { |t| t == transaction }

      found_transaction.prev_hash = transaction.prev_hash
      found_transaction
    end

    include Logger
    include TransactionModels
  end
end
