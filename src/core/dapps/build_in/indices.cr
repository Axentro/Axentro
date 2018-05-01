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
      false
    end

    def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
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

      result = if block_index = get(transaction_id)
                 if transaction = blockchain.chain[block_index].find_transaction(transaction_id)
                   {found: true, transaction: transaction}
                 else
                   {found: false}
                 end
               else
                 {found: false}
               end

      context.response.print api_success(result)
      context
    end

    def confirmation(json, context, params)
      transaction_id = json["transaction_id"].as_s

      unless block_index = get(transaction_id)
        raise "failed to find a block for the transaction #{transaction_id}"
      end

      latest_index = @indices.size

      result = {
        confirmed:     (latest_index - block_index) >= UTXO::CONFIRMATION,
        confirmations: latest_index - block_index,
        threshold:     UTXO::CONFIRMATION,
      }

      context.response.print api_success(result)
      context
    end
  end
end
