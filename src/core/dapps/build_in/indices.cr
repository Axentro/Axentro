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

module ::Sushi::Core::DApps::BuildIn
  class Indices < DApp
    @indices : Array(Hash(String, Int64)) = Array(Hash(String, Int64)).new

    def setup
    end

    def get(transaction_id : String) : Int64?
      @indices.reverse.each do |indices|
        return indices[transaction_id] if indices[transaction_id]?
      end

      nil
    end

    def transaction_actions : Array(String)
      [] of String
    end

    def transaction_related?(action : String) : Bool
      true
    end

    def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      if index = get(transaction.id)
        raise "the transaction #{transaction.id} is already included in #{index}"
      end

      if prev_transactions.count { |t| t.id == transaction.id } > 0
        raise "the transaction #{transaction.id} already exists in the same block"
      end

      true
    end

    def record(chain : Blockchain::Chain)
      return if @indices.size >= chain.size

      chain[@indices.size..-1].each do |block|
        @indices.push(Hash(String, Int64).new)

        block.transactions.each do |transaction|
          @indices[-1][transaction.id] = block.index
        end
      end
    end

    def clear
      @indices.clear
    end

    def define_rpc?(call, json, context, params)
      case call
      when "transaction"
        return transaction(json, context, params)
      when "confirmation"
        return confirmation(json, context, params)
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
        if transaction = blockchain.chain[block_index].find_transaction(transaction_id)
          return {
            status:      "accepted",
            transaction: transaction,
          }
        end
      end

      if transaction = (blockchain.pending_slow_transactions + blockchain.pending_fast_transactions).find { |t| t.id == transaction_id }
        return {
          status:      "pending",
          transaction: transaction,
        }
      end

      if rejected_reason = blockchain.rejects.find(transaction_id)
        return {
          status:      "rejected",
          transaction: nil,
          reason:      rejected_reason,
        }
      end

      {
        status:      "not found",
        transaction: nil,
      }
    end

    def confirmation(json, context, params)
      transaction_id = json["transaction_id"].as_s

      context.response.print api_success(confirmation_impl(transaction_id))
      context
    end

    def confirmation_impl(transaction_id : String)
      unless block_index = get(transaction_id)
        raise "failed to find a block for the transaction #{transaction_id}"
      end

      latest_index = @indices.size

      {
        confirmations: latest_index - block_index,
      }
    end

    def on_message(action : String, from_address : String, content : String, from = nil)
      false
    end
  end
end
