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
  class TransactionPool < Tokoroten::Worker
    @@worker : Tokoroten::Worker? = nil

    @pool : Transactions = Transactions.new
    @pool_locked : Transactions = Transactions.new

    @locked : Bool = false

    alias TxPoolWork = NamedTuple(call: Int32, content: String)

    def self.setup
      @@worker ||= TransactionPool.create(1)[0]
    end

    def self.worker : Tokoroten::Worker
      @@worker.not_nil!
    end

    def self.create_request(protocol : TXP, content)
      {call: protocol, content: content.to_json}.to_json
    end

    def self.add(transaction : Transaction)
      request = create_request(TXP::ADD, { transaction: transaction })
      worker.exec(request)
    end

    def add(content : String)
      request = TXP_REQ_ADD.from_json(content)
      transaction = request.transaction

      if @locked
        @pool_locked << transaction
      else
        @pool << transaction
      end
    end

    def self.delete(transaction : Transaction)
      request = create_request(TXP::DELETE, { transaction: transaction })
      worker.exec(request)
    end

    def delete(content : String)
      request = TXP_REQ_DELETE.from_json(content)
      transaction = request.transaction

      @pool.reject! { |t| t.id == transaction.id }
    end

    def self.replace(transactions : Transactions)
      request = create_request(TXP::REPLACE, { transactions: transactions })
      worker.exec(request)
    end

    def replace(content : String)
      request = TXP_REQ_REPLACE.from_json(content)
      transactions = request.transactions

      @pool = transactions
      @pool.concat(@pool_locked)

      @locked = false

      @pool_locked.clear
    end

    def self.all
      request = create_request(TXP::ALL, "")
      worker.exec(request)
    end

    def all
      response({ transactions: @pool }.to_json)
    end

    def self.align(coinbase_transaction : Transaction, coinbase_amount : Int64)
      request = create_request(TXP::ALIGN,
                               {
                                 coinbase_transaction: coinbase_transaction,
                                 coinbase_amount: coinbase_amount
                               })
      worker.exec(request)
    end

    def align(content : String)
      request = TXP_REQ_ALIGN.from_json(content)

      coinbase_transaction = request.coinbase_transaction
      coinbase_amount = request.coinbase_amount

      aligned_transactions = [coinbase_transaction]

      rejects = [] of NamedTuple(transaction_id: String, reason: String)

      @pool.each do |t|
        t.prev_hash = aligned_transactions[-1].to_hash
        t.valid_without_dapps?(coinbase_amount, aligned_transactions)

        aligned_transactions << t
      rescue e : Exception
        rejects << { transaction_id: t.id, reason: e.message || "unknown" }
      end

      response({ transactions: aligned_transactions, rejects: rejects }.to_json)
    end

    def self.validate(coinbase_amount : Int64, transactions : Transactions)
      request = create_request(TXP::VALIDATE,
                               {
                                 coinbase_amount: coinbase_amount,
                                 transactions: transactions,
                               })
      worker.exec(request)
    end

    def validate(content : String)
      request = TXP_REQ_VALIDATE.from_json(content)

      coinbase_amount = request.coinbase_amount

      transactions = request.transactions
      transactions.each_with_index do |t, idx|
        t.valid_without_dapps?(coinbase_amount, idx == 0 ? [] of Transaction : transactions[0..idx - 1])
      rescue e : Exception
        return response({ valid: false, reason: e.message.not_nil! }.to_json)
      end

      response({ valid: true, reason: "" }.to_json)
    end

    def self.lock
      request = create_request(TXP::LOCK, "")
      worker.exec(request)
    end

    def lock
      @locked = true
    end

    def self.receive
      worker.receive
    end

    def task(message : String)
      json = TxPoolWork.from_json(message)

      case json[:call]
      when TXP::ADD.to_i
        add(json[:content])
      when TXP::DELETE.to_i
        delete(json[:content])
      when TXP::REPLACE.to_i
        replace(json[:content])
      when TXP::ALL.to_i
        all
      when TXP::ALIGN.to_i
        align(json[:content])
      when TXP::VALIDATE.to_i
        validate(json[:content])
      when TXP::LOCK.to_i
        lock
      end
    rescue e : Exception
      error e.message.not_nil!
      error e.backtrace.join("n")
    end

    include Logger
    include Protocol
    include TransactionModels
  end
end
