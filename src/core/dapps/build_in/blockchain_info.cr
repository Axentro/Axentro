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
  class BlockchainInfo < DApp
    def setup
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
    end

    def clear
    end

    # TODO - handle fast and slow chain sizes here
    def define_rpc?(call, json, context, params)
      case call
      when "blockchain_size"
        return blockchain_size(json, context, params)
      when "blockchain"
        return blockchain(json, context, params)
      when "block"
        return block(json, context, params)
      when "transactions"
        return transactions(json, context, params)
      end

      nil
    end

    def blockchain_size(json, context, params)
      context.response.print api_success(blockchain_size_impl)
      context
    end

    def blockchain_size_impl
      {size: blockchain.chain.size}
    end

    def blockchain(json, context, params)
      context.response.print api_success(blockchain_impl(json["header"].as_bool))
      context
    end

    def blockchain_impl(header : Bool)
      if header
        blockchain.headers
      else
        blockchain.chain
      end
    end

    def block(json, context, params)
      context.response.print api_success(
        block_impl(json["header"].as_bool, json["index"]?, json["transaction_id"]?)
      )
      context
    end

    def block_impl(header : Bool, _index, _transaction_id)
      if index = _index
        block_impl(header, index.as_i64)
      elsif transaction_id = _transaction_id
        block_impl(header, transaction_id.as_s)
      else
        raise "please specify block index or transaction id"
      end
    end

    def block_impl(header : Bool, index : Int64)
      if index > blockchain.chain.size - 1
        raise "invalid index #{index} (blockchain size is #{blockchain.chain.size})"
      end

      block = blockchain.chain[index]

      header ? block.to_header : block
    end

    def block_impl(header : Bool, transaction_id : String)
      unless block_index = blockchain.indices.get(transaction_id)
        raise "failed to find a block for the transaction #{transaction_id}"
      end

      header ? blockchain.chain[block_index].to_header : blockchain.chain[block_index]
    end

    def transactions(json, context, params)
      context.response.print api_success(transactions_impl(json["index"]?, json["address"]?))
      context
    end

    def transactions_impl(_index, _address)
      if index = _index
        transactions_impl(index.as_i64)
      elsif address = _address
        transactions_impl(address.as_s)
      else
        raise "please specify a block index or an address"
      end
    end

    def transactions_impl(index : Int64)
      if index > blockchain.chain.size - 1
        raise "invalid index #{index} (blockchain size is #{blockchain.chain.size})"
      end

      blockchain.chain[index].transactions
    end

    def transactions_impl(address : String, page : Int32 = 0, page_size : Int32 = 20, actions : Array(String) = [] of String)
      blockchain.transactions_for_address(address, page, page_size, actions)
    end

    def on_message(action : String, from_address : String, content : String, from = nil)
      false
    end
  end
end
