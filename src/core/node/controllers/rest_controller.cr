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
  # [POST] v1/transaction                             | create and broadcast a transaction
  # [POST] v1/transaction/unsigned                    | create an unsigned transaction
  #
  # --- address
  #
  # [GET] v1/address/{:address}/transactions          | transactions for address
  # [GET] v1/address/{:address}/confirmed             | confirmed amount for address for all tokens
  # [GET] v1/address/{:address}/confirmed/{:token}    | confirmed amount for address for the token
  # [GET] v1/address/{:address}/unconfirmed           | unconfirmed amount for address for all tokens
  # [GET] v1/address/{:address}/unconfirmed/{:token}  | unconfirmed amount for address for all tokens for the token
  #
  # --- scars
  #
  # [GET] v1/scars/sales                              | get all scars's domains for sales
  # [GET] v1/scars/{:domain}/confirmed                | get the confirmed status of the domain
  # [GET] v1/scars/{:domain}/unconfirmed              | get the unconfirmed status of the domain
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
      get "/v1/domain/:domain/transactions" { |context, params| __v1_domain_transactions(context, params) }
      get "/v1/domain/:domain/confirmed" { |context, params| __v1_domain_confirmed(context, params) }
      get "/v1/domain/:domain/confirmed/:token" { |context, params| __v1_domain_confirmed_token(context, params) }
      get "/v1/domain/:domain/unconfirmed" { |context, params| __v1_domain_unconfirmed(context, params) }
      get "/v1/domain/:domain/unconfirmed/:token" { |context, params| __v1_domain_unconfirmed_token(context, params) }
      get "/v1/scars/sales" { |context, params| __v1_scars_sales(context, params) }
      get "/v1/scars/:domain/confirmed" { |context, params| __v1_scars_confirmed(context, params) }
      get "/v1/scars/:domain/unconfirmed" { |context, params| __v1_scars_unconfirmed(context, params) }

      post "/v1/transaction" { |context, params| __v1_transaction(context, params) }
      post "/v1/transaction/unsigned" { |context, params| __v1_transaction_unsigned(context, params) }

      route_handler
    end

    def __v1_blockchain(context, params)
      with_response(context) do
        @blockchain.blockchain_info.blockchain_impl(false)
      end
    end

    def __v1_blockchain_header(context, params)
      with_response(context) do
        @blockchain.blockchain_info.blockchain_impl(true)
      end
    end

    def __v1_blockchain_size(context, params)
      with_response(context) do
        @blockchain.blockchain_info.blockchain_size_impl
      end
    end

    def __v1_block_index(context, params)
      with_response(context) do
        index = params["index"].to_i64
        @blockchain.blockchain_info.block_impl(false, index)
      end
    end

    def __v1_block_index_header(context, params)
      with_response(context) do
        index = params["index"].to_i64
        @blockchain.blockchain_info.block_impl(true, index)
      end
    end

    def __v1_block_index_transactions(context, params)
      with_response(context) do
        index = params["index"].to_i64
        @blockchain.blockchain_info.transactions_impl(index)
      end
    end

    def __v1_transaction_id(context, params)
      with_response(context) do
        id = params["id"]
        @blockchain.indices.transaction_impl(id)
      end
    end

    def __v1_transaction_id_block(context, params)
      with_response(context) do
        id = params["id"]
        @blockchain.blockchain_info.block_impl(false, id)
      end
    end

    def __v1_transaction_id_block_header(context, params)
      with_response(context) do
        id = params["id"]
        @blockchain.blockchain_info.block_impl(true, id)
      end
    end

    def __v1_transaction_id_confirmations(context, params)
      with_response(context) do
        id = params["id"]
        @blockchain.indices.confirmation_impl(id)
      end
    end

    def __v1_transaction_fees(context, params)
      with_response(context) do
        @blockchain.fees.fees_impl
      end
    end

    def __v1_transaction(context, params)
      with_response(context) do
        json = parse_body(context)

        @blockchain.transaction_creator.create_transaction_impl(
          Core::Transaction.from_json(json["transaction"].to_json)
        )
      end
    end

    def __v1_transaction_unsigned(context, params)
      with_response(context) do
        json = parse_body(context)

        @blockchain.transaction_creator.create_unsigned_transaction_impl(
          json["action"].as_s,
          Core::Transaction::Senders.from_json(json["senders"].to_json),
          Core::Transaction::Recipients.from_json(json["recipients"].to_json),
          json["message"].as_s,
          json["token"].as_s,
        )
      end
    end

    def __v1_address_transactions(context, params)
      with_response(context) do |query_params|
        page = query_params["page"]?.try &.to_i || 0
        page_size = query_params["page_size"]?.try &.to_i || 20

        address = params["address"]
        @blockchain.blockchain_info.transactions_impl(address, page, page_size)
      end
    end

    def __v1_address_confirmed(context, params)
      with_response(context) do
        address = params["address"]
        @blockchain.utxo.amount_impl(address, true, "all")
      end
    end

    def __v1_address_confirmed_token(context, params)
      with_response(context) do
        address = params["address"]
        token = params["token"]
        @blockchain.utxo.amount_impl(address, true, token)
      end
    end

    def __v1_address_unconfirmed(context, params)
      with_response(context) do
        address = params["address"]
        @blockchain.utxo.amount_impl(address, false, "all")
      end
    end

    def __v1_address_unconfirmed_token(context, params)
      with_response(context) do
        address = params["address"]
        token = params["token"]
        @blockchain.utxo.amount_impl(address, false, token)
      end
    end

    def __v1_domain_transactions(context, params)
      with_response(context) do |query_params|
        page = query_params["page"]?.try &.to_i || 0
        page_size = query_params["page_size"]?.try &.to_i || 20

        domain = params["domain"]
        address = convert_domain_to_address(domain)
        @blockchain.blockchain_info.transactions_impl(address, page, page_size)
      end
    end

    def __v1_domain_confirmed(context, params)
      with_response(context) do
        domain = params["domain"]
        address = convert_domain_to_address(domain)
        @blockchain.utxo.amount_impl(address, true, "all")
      end
    end

    def __v1_domain_confirmed_token(context, params)
      with_response(context) do
        domain = params["domain"]
        token = params["token"]
        address = convert_domain_to_address(domain)
        @blockchain.utxo.amount_impl(address, true, token)
      end
    end

    def __v1_domain_unconfirmed(context, params)
      with_response(context) do
        domain = params["domain"]
        address = convert_domain_to_address(domain)
        @blockchain.utxo.amount_impl(address, false, "all")
      end
    end

    def __v1_domain_unconfirmed_token(context, params)
      with_response(context) do
        domain = params["domain"]
        token = params["token"]
        address = convert_domain_to_address(domain)
        @blockchain.utxo.amount_impl(address, false, token)
      end
    end

    def __v1_scars_sales(context, params)
      with_response(context) do
        @blockchain.scars.scars_for_sale_impl
      end
    end

    def __v1_scars_confirmed(context, params)
      domain = params["domain"]

      with_response(context) do
        @blockchain.scars.scars_resolve_impl(domain, true)
      end
    end

    def __v1_scars_unconfirmed(context, params)
      domain = params["domain"]

      with_response(context) do
        @blockchain.scars.scars_resolve_impl(domain, false)
      end
    end

    private def with_response(context, &block)
      query_params = HTTP::Params.parse(context.request.query || "")

      context.response.headers["Allow"] = "HEAD,GET,PUT,POST,DELETE,OPTIONS"
      context.response.headers["Access-Control-Allow-Origin"] = "*"
      context.response.headers["Access-Control-Allow-Headers"] =
        "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept"
      context.response.print api_success(yield query_params)
      context
    rescue e : Exception
      rest_error(context, e)
    end

    private def rest_error(context, e : Exception)
      error_message = if message = e.message
                        message
                      else
                        "unknown error"
                      end

      context.response.print api_error(error_message)
      context
    end

    private def parse_body(context) : JSON::Any
      raise "empty body" unless body = context.request.body
      raise "empty payload" unless payload = body.gets

      JSON.parse(payload)
    end

    private def convert_domain_to_address(domain : String) : String
      resolved = @blockchain.scars.scars_resolve_impl(domain, true)
      raise "the domain #{domain} is not resolved" unless resolved[:resolved]

      resolved[:domain][:address]
    end

    include Router
    include NodeComponents::APIFormat
  end
end
