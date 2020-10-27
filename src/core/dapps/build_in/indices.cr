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

module ::Axentro::Core::DApps::BuildIn
  class Indices < DApp
    def setup
    end

    def get(transaction_id : String) : Int64?
      database.get_block_index_for_transaction(transaction_id)
    end

    def transaction_actions : Array(String)
      [] of String
    end

    def transaction_related?(action : String) : Bool
      true
    end

    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      existing_transactions = database.get_transactions_and_block_that_exist(transactions)

      failed = [] of FailedTransaction

      transactions.each do |transaction|
        existing_transactions.each do |existing_transaction|
          if existing_transaction.transaction.id == transaction.id
            failed << FailedTransaction.new(transaction, "the transaction #{transaction.id} already exists in block: #{existing_transaction.block}")
          end
        end
      end

      transactions.map(&.id).tally.select { |_, v| v > 1 }.keys.each do |transaction_id|
        failed << FailedTransaction.new(transactions.find { |t| t.id == transaction_id }.not_nil!, "the transaction #{transaction_id} already exists in the same block")
      end

      passed = transactions.reject { |t| failed.map(&.transaction.id).includes?(t.id) }

      ValidatedTransactions.new(failed, passed)
    end

    def record(chain : Blockchain::Chain)
    end

    def clear
    end

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
      case call
      when "transaction"
        return transaction(json, context, params)
      end

      nil
    end

    def transaction(json, context, params)
      transaction_id = json["transaction_id"].as_s

      context.response.print api_success(transaction_impl(transaction_id))
      context
    end

    def transaction_impl(transaction_id : String)
      if block_index = get(transaction_id)
        if block = database.get_block(block_index)
          if transaction = block.find_transaction(transaction_id)
            confirmations = database.get_confirmations(block_index)
            return {
              status:        "accepted",
              confirmations: confirmations,
              transaction:   transaction,
            }
          end
        end
      end

      if transaction = (blockchain.pending_slow_transactions + blockchain.pending_fast_transactions).find { |t| t.id == transaction_id }
        confirmations = 0
        if block_index = database.get_block_index_for_transaction(transaction.id)
          confirmations = database.get_confirmations(block_index)
        end

        return {
          status:        "pending",
          confirmations: confirmations,
          transaction:   transaction,
        }
      end

      if reject = blockchain.rejects.find(transaction_id)
        return {
          status:      "rejected",
          transaction: nil,
          reason:      reject.reason,
        }
      end

      {
        status:      "not found",
        transaction: nil,
      }
    end

    def on_message(action : String, from_address : String, content : String, from = nil)
      false
    end
  end
end
