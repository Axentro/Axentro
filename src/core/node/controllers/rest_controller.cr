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

module ::Sushi::Core::Controllers
  #
  # REST controller version 1.
  #
  # --- blockchain
  #
  # [GET] v1/blockchain                               | full blockchain
  # [GET] v1/blockchain/header                        | blockchain headers
  # [GET] v1/blockchain/size                          | blockchain size
  #
  # --- block
  #
  # [GET] v1/block/{:index}                           | full block at index
  # [GET] v1/block/{:index}/header                    | block header at index
  # [GET] v1/block/{:index}/transactions              | transactions in block
  #
  # --- transaction
  #
  # [GET] v1/transaction/{:id}                        | transaction for supplied txn id
  # [GET] v1/transaction/{:id}/block                  | full block containing txn id
  # [GET] v1/transaction/{:id}/block/header           | block header containing txn id
  # [GET] v1/transaction/{:id}/confirmations          | number confirmations for txn id
  # [GET] v1/transaction/fees                         | fees
  #
  # --- address
  #
  # [GET] v1/address/{:address}/transactions          | transactions for address
  # [GET] v1/address/{:address}/confirmed             | confirmed amount for address for all tokens
  # [GET] v1/address/{:address}/confirmed/{:token}    | confirmed amount for address for the token
  # [GET] v1/address/{:address}/unconfirmed           | unconfirmed amount for address for all tokens
  # [GET] v1/address/{:address}/unconfirmed/{:token}  | unconfirmed amount for address for all tokens for the token
  #
  class RESTController
    def initialize(@blockchain : Blockchain)
    end

    def node
      @blockchain.node
    end

    def get_handler
      get "/v1/blockchain" { |context, params| __v1_blockchain(context, params) }
      get "/v1/blockchain/header" { |context, params| __v1_blockchain_header(context, params) }
      get "/v1/blockchain/size" { |context, params| __v1_blockchain_size(context, params) }
      get "/v1/block/:index" { |context, params| __v1_block_index(context, params) }
      get "/v1/block/:index/header" { |context, params| __v1_block_index_header(context, params) }
      get "/v1/block/:index/transactions" { |context, params| __v1_block_index_transactions(context, params) }
      get "/v1/transaction/:id" { |context, params| __v1_transaction_id(context, params) }
      get "/v1/transaction/:id/block" { |context, params| __v1_transaction_id_block(context, params) }
      get "/v1/transaction/:id/block/header" { |context, params| __v1_transaction_id_block_header(context, params) }
      get "/v1/transaction/:id/confirmations" { |context, params| __v1_transaction_id_confirmations(context, params) }
      get "/v1/transaction/fees" { |context, params| __v1_transaction_fees(context, params) }
      get "/v1/address/:address/transactions" { |context, params| __v1_address_transactions(context, params) }
      get "/v1/address/:address/confirmed" { |context, params| __v1_address_confirmed(context, params) }
      get "/v1/address/:address/confirmed/:token" { |context, params| __v1_address_confirmed_token(context, params) }
      get "/v1/address/:address/unconfirmed" { |context, params| __v1_address_unconfirmed(context, params) }
      get "/v1/address/:address/unconfirmed/:token" { |context, params| __v1_address_unconfirmed_token(context, params) }

      route_handler
    end

    def __v1_blockchain(context, params)
      context.response.print api_success(@blockchain.blockchain_info.blockchain_impl(false))
      context
    rescue e : Exception
      rest_error(context, e)
    end

    def __v1_blockchain_header(context, params)
      context.response.print api_success(@blockchain.blockchain_info.blockchain_impl(true))
      context
    rescue e : Exception
      rest_error(context, e)
    end

    def __v1_blockchain_size(context, params)
      context.response.print api_success(@blockchain.blockchain_info.blockchain_size_impl)
      context
    rescue e : Exception
      rest_error(context, e)
    end

    def __v1_block_index(context, params)
      index = params["index"].to_i64

      context.response.print api_success(@blockchain.blockchain_info.block_impl(false, index))
      context
    rescue e : Exception
      rest_error(context, e)
    end

    def __v1_block_index_header(context, params)
      index = params["index"].to_i64

      context.response.print api_success(@blockchain.blockchain_info.block_impl(true, index))
      context
    rescue e : Exception
      rest_error(context, e)
    end

    def __v1_block_index_transactions(context, params)
      index = params["index"].to_i64

      context.response.print api_success(@blockchain.blockchain_info.transactions_impl(index))
      context
    rescue e : Exception
      rest_error(context, e)
    end

    def __v1_transaction_id(context, params)
      id = params["id"]

      context.response.print api_success(@blockchain.indices.transaction_impl(id))
      context
    rescue e : Exception
      rest_error(context, e)
    end

    def __v1_transaction_id_block(context, params)
      id = params["id"]

      context.response.print api_success(@blockchain.blockchain_info.block_impl(false, id))
      context
    rescue e : Exception
      rest_error(context, e)
    end

    def __v1_transaction_id_block_header(context, params)
      id = params["id"]

      context.response.print api_success(@blockchain.blockchain_info.block_impl(true, id))
      context
    rescue e : Exception
      rest_error(context, e)
    end

    def __v1_transaction_id_confirmations(context, params)
      id = params["id"]

      context.response.print api_success(@blockchain.indices.confirmation_impl(id))
      context
    rescue e : Exception
      rest_error(context, e)
    end

    def __v1_transaction_fees(context, params)
      context.response.print api_success(@blockchain.fees.fees_impl)
      context
    rescue e : Exception
      rest_error(context, e)
    end

    def __v1_address_transactions(context, params)
      address = params["address"]

      context.response.print api_success(@blockchain.blockchain_info.transactions_impl(address))
      context
    rescue e : Exception
      rest_error(context, e)
    end

    def __v1_address_confirmed(context, params)
      address = params["address"]

      context.response.print api_success(@blockchain.utxo.amount_impl(address, true, "all"))
      context
    rescue e : Exception
      rest_error(context, e)
    end

    def __v1_address_confirmed_token(context, params)
      address = params["address"]
      token = params["token"]

      context.response.print api_success(@blockchain.utxo.amount_impl(address, true, token))
      context
    rescue e : Exception
      rest_error(context, e)
    end

    def __v1_address_unconfirmed(context, params)
      address = params["address"]

      context.response.print api_success(@blockchain.utxo.amount_impl(address, false, "all"))
      context
    rescue e : Exception
      rest_error(context, e)
    end

    def __v1_address_unconfirmed_token(context, params)
      address = params["address"]
      token = params["token"]

      context.response.print api_success(@blockchain.utxo.amount_impl(address, false, token))
      context
    rescue e : Exception
      rest_error(context, e)
    end

    def rest_error(context, e : Exception)
      error_message = if message = e.message
                        message
                      else
                        "unknown error"
                      end

      context.response.print api_error(error_message)
      context
    end

    include Router
    include NodeComponents::APIFormat
  end
end
