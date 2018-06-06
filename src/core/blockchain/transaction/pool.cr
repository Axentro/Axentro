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

    alias TxPoolWork = NamedTuple(call: Int32, content: String)

    enum Protocol
      TXP_ADD
      TXP_DELETE
      TXP_ALL
      TXP_FIND
      TXP_ALIGN
    end

    def delete(content : String)
      transaction = Transaction.from_json(content)
      @pool.delete(transaction)
    end

    def add(content : String)
      transaction = Transaction.from_json(content)
      @pool << transaction
    end

    def all
      response(@pool.to_json)
    end

    def find(content : String)
      json = JSON.parse(content)
      transaction_id = json["transaction_id"].as_s

      if transaction = @pool.find { |transaction| transaction.id == transaction_id }
        response(transaction.to_json)
      else
        response("")
      end
    end

    def align(content : String)
      # todo
    end

    def task(message : String)
      json = TxPoolWork.from_json(message)

      case json[:call]
      when Protocol::TXP_ADD.to_i
        add(json[:content])
      when Protocol::TXP_DELETE.to_i
        delete(json[:content])
      when Protocol::TXP_ALL.to_i
        all
      when Protocol::TXP_FIND.to_i
        find(json[:content])
      when Protocol::TXP_ALIGN.to_i
        align(json[:content])
      end
    rescue e : Exception
      error e.message.not_nil!
      error e.backtrace.join("n")
    end

    include Logger
  end
end
