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

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
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
      {totals:       {total_size: database.total_blocks, total_fast: database.total(Block::BlockKind::FAST), total_slow: database.total(Block::BlockKind::SLOW)},
       block_height: {slow: database.highest_index_of_kind(Block::BlockKind::SLOW),
                      fast: database.highest_index_of_kind(Block::BlockKind::FAST)}}
    end

    def blockchain(json, context, params)
      page, per_page, direction = 0, 50, 1

      context.response.print api_success(blockchain_impl(json["header"].as_bool, page, per_page, direction))
      context
    end

    def blockchain_impl(header : Bool, page, per_page, direction)
      if header
        database.get_paginated_blocks(page, per_page, Direction.new(direction).to_s).map(&.to_header)
      else
        database.get_paginated_blocks(page, per_page, Direction.new(direction).to_s)
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
        block_index_impl(header, index.as_i64)
      elsif transaction_id = _transaction_id
        block_transaction_impl(header, transaction_id.as_s)
      else
        raise "please specify block index or transaction id"
      end
    end

    def block_index_impl(header : Bool, block_index : Int64)
      if block = database.get_block(block_index)
        header ? block.to_header : block
      else
        raise "failed to find a block for the index: #{block_index}"
      end
    end

    def block_transaction_impl(header : Bool, transaction_id : String)
      if block = database.get_block_for_transaction(transaction_id)
        header ? block.to_header : block
      else
        raise "failed to find a block for the transaction #{transaction_id}"
      end
    end

    def transactions(json, context, params)
      page, per_page, direction = 0, 50, 1
      context.response.print api_success(transactions_impl(json["index"]?, json["address"]?, page, per_page, direction))
      context
    end

    def transactions_impl(_index, _address, page, per_page, direction)
      if index = _index
        transactions_index_impl(index.as_i64, page, per_page, direction)
      elsif address = _address
        transactions_address_impl(address.as_s, page, per_page, direction)
      else
        raise "please specify a block index or an address"
      end
    end

    def transactions_index_impl(block_index : Int64, page : Int32, per_page : Int32, direction : Int32)
      database.get_paginated_transactions(block_index, page, per_page, Direction.new(direction).to_s)
    end

    def transactions_address_impl(address : String, page : Int32, per_page : Int32, direction : Int32, actions : Array(String) = [] of String)
      database.get_paginated_transactions_for_address(address, page, per_page, Direction.new(direction).to_s, actions)
    end

    def on_message(action : String, from_address : String, content : String, from = nil)
      false
    end
  end

  include NodeComponents::APIParams
end
