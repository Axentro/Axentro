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

    def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      if index = get(transaction.id)
        raise "the transaction #{transaction.id} is already included in block: #{index}"
      end

      if prev_transactions.count { |t| t.id == transaction.id } > 0
        raise "the transaction #{transaction.id} already exists in the same block"
      end

      true
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
