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
    alias Transactions = Array(Transaction)

    @pool : Transactions = Transactions.new

    @@worker : Tokoroten::Worker? = nil

    alias TxPoolWork = NamedTuple(call: Int32, content: String)

    enum Protocol
      TXP_ADD
      TXP_DELETE
      TXP_REPLACE
      TXP_ALL
      TXP_ALIGN
    end

    def self.setup
      @@worker ||= TransactionPool.create(1)[0]
    end

    def self.worker : Tokoroten::Worker
      @@worker.not_nil!
    end

    def self.create_request(protocol : Protocol, content)
      {call: protocol, content: content.to_json}.to_json
    end

    def self.add(transaction : Transaction)
      request = create_request(Protocol::TXP_ADD, transaction)
      worker.exec(request)
    end

    def add(content : String)
      transaction = Transaction.from_json(content)
      @pool << transaction
    end

    def self.delete(transaction : Transaction)
      request = create_request(Protocol::TXP_DELETE, transaction)
      worker.exec(request)
    end

    def delete(content : String)
      transaction = Transaction.from_json(content)
      @pool.reject! { |t| t.id == transaction.id }
    end

    def self.replace(transactions : Transactions)
      request = create_request(Protocol::TXP_REPLACE, transactions)
      worker.exec(request)
    end

    def replace(content : String)
      transactions = Transactions.from_json(content)
      @pool = transactions
    end

    def self.all
      request = create_request(Protocol::TXP_ALL, "")
      worker.exec(request)
    end

    def all
      response(@pool.to_json)
    end

    def self.align
      request = create_request(Protocol::TXP_ALIGN, "")
      worker.exec(request)
    end

    def align
      # response some
    end

    def self.receive
      worker.receive
    end

    def task(message : String)
      json = TxPoolWork.from_json(message)

      p "----------------- task #{json[:call]} ----------------------"
      #
      # TODO:
      # fix Protocol.**to_i**
      #
      case json[:call]
      when Protocol::TXP_ADD.to_i
        p "--> add"
        add(json[:content])
      when Protocol::TXP_DELETE.to_i
        p "--> delete"
        delete(json[:content])
      when Protocol::TXP_REPLACE.to_i
        p "--> replace"
        replace(json[:content])
      when Protocol::TXP_ALL.to_i
        p "--> all"
        all
      when Protocol::TXP_ALIGN.to_i
        p "--> align"
        align
      end
    rescue e : Exception
      error e.message.not_nil!
      error e.backtrace.join("n")
    end

    include Logger
  end
end
