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
  # [GET] api/v1/blockchain                               | full blockchain
  # [GET] api/v1/blockchain/header                        | blockchain headers
  # [GET] api/v1/blockchain/size                          | blockchain size
  #
  # --- block
  #
  # [GET] api/v1/block/{:index}                           | full block at index
  # [GET] api/v1/block/{:index}/header                    | block header at index
  # [GET] api/v1/block/{:index}/transactions              | transactions in block
  #
  # --- transaction
  #
  # [GET] api/v1/transaction/{:id}                        | transaction for supplied txn id
  # [GET] api/v1/transaction/{:id}/block                  | full block containing txn id
  # [GET] api/v1/transaction/{:id}/block/header           | block header containing txn id
  # [GET] api/v1/transaction/{:id}/confirmations          | number confirmations for txn id
  # [GET] api/v1/transaction/fees                         | fees
  # [POST] api/v1/transaction                             | create and broadcast a transaction
  # [POST] api/v1/transaction/unsigned                    | create an unsigned transaction
  #
  # --- address
  #
  # [GET] api/v1/address/{:address}                       | amount for address for all tokens
  # [GET] api/v1/address/{:address}/token/{:token}        | amount for address for the token
  # [GET] api/v1/address/{:address}/transactions          | transactions for address
  #
  # --- domain
  #
  # [GET] api/v1/domain/{:domain}                       | amount for domain for all tokens
  # [GET] api/v1/domain/{:domain}/token/{:token}        | amount for domain for the token
  # [GET] api/v1/domain/{:domain}/transactions          | transactions for domain
  #
  # --- scars
  #
  # [GET] api/v1/scars/sales                              | get all scars's domains for sales
  # [GET] api/v1/scars/{:domain}                          | get the status of the domain
  #
  class RESTController
    def initialize(@blockchain : Blockchain)
    end

    def node
      @blockchain.node
    end

    def get_handler
      get "/api/v1/blockchain" { |context, params| __v1_blockchain(context, params) }
      get "/api/v1/blockchain/header" { |context, params| __v1_blockchain_header(context, params) }
      get "/api/v1/blockchain/size" { |context, params| __v1_blockchain_size(context, params) }
      get "/api/v1/block/:index" { |context, params| __v1_block_index(context, params) }
      get "/api/v1/block/:index/header" { |context, params| __v1_block_index_header(context, params) }
      get "/api/v1/block/:index/transactions" { |context, params| __v1_block_index_transactions(context, params) }
      get "/api/v1/transaction/:id" { |context, params| __v1_transaction_id(context, params) }
      get "/api/v1/transaction/:id/block" { |context, params| __v1_transaction_id_block(context, params) }
      get "/api/v1/transaction/:id/block/header" { |context, params| __v1_transaction_id_block_header(context, params) }
      get "/api/v1/transaction/:id/confirmations" { |context, params| __v1_transaction_id_confirmations(context, params) }
      get "/api/v1/transaction/fees" { |context, params| __v1_transaction_fees(context, params) }
      get "/api/v1/address/:address" { |context, params| __v1_address(context, params) }
      get "/api/v1/address/:address/token/:token" { |context, params| __v1_address_token(context, params) }
      get "/api/v1/address/:address/transactions" { |context, params| __v1_address_transactions(context, params) }
      get "/api/v1/domain/:domain" { |context, params| __v1_domain(context, params) }
      get "/api/v1/domain/:domain/token/:token" { |context, params| __v1_domain_token(context, params) }
      get "/api/v1/domain/:domain/transactions" { |context, params| __v1_domain_transactions(context, params) }
      get "/api/v1/scars/sales" { |context, params| __v1_scars_sales(context, params) }
      get "/api/v1/scars/:domain" { |context, params| __v1_scars(context, params) }
      get "/api/v1/tokens" { |context, params| __v1_tokens(context, params) }
      get "/api/v1/nodes" { |context, params| __v1_nodes(context, params) }
      get "/api/v1/node" { |context, params| __v1_node(context, params) }
      get "/api/v1/node/:id" { |context, params| __v1_node_id(context, params) }

      post "/api/v1/transaction" { |context, params| __v1_transaction(context, params) }
      post "/api/v1/transaction/unsigned" { |context, params| __v1_transaction_unsigned(context, params) }

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
          SendersDecimal.from_json(json["senders"].to_json),
          RecipientsDecimal.from_json(json["recipients"].to_json),
          json["message"].as_s,
          json["token"].as_s,
          TransactionKind.parse(json["kind"].as_s)
        )
      end
    end

    def __v1_address_transactions(context, params)
      with_response(context) do |query_params|
        page = query_params["page"]?.try &.to_i || 0
        page_size = query_params["page_size"]?.try &.to_i || 20
        actions = query_params["actions"]?.try &.split(",") || [] of String

        address = params["address"]
        @blockchain.blockchain_info.transactions_impl(address, page, page_size, actions)
      end
    end

    def __v1_address(context, params)
      with_response(context) do |query_params|
        address = params["address"]
        confirmation = query_params["confirmation"]?.try &.to_i || 1
        @blockchain.utxo.amount_impl(address, "all", confirmation)
      end
    end

    def __v1_address_token(context, params)
      with_response(context) do |query_params|
        address = params["address"]
        token = params["token"]
        confirmation = query_params["confirmation"]?.try &.to_i || 1
        @blockchain.utxo.amount_impl(address, token, confirmation)
      end
    end

    def __v1_domain_transactions(context, params)
      with_response(context) do |query_params|
        page = query_params["page"]?.try &.to_i || 0
        page_size = query_params["page_size"]?.try &.to_i || 20
        actions = query_params["actions"]?.try &.split(",") || [] of String
        confirmation = query_params["confirmation"]?.try &.to_i || 1

        domain = params["domain"]
        address = convert_domain_to_address(domain, confirmation)
        @blockchain.blockchain_info.transactions_impl(address, page, page_size, actions)
      end
    end

    def __v1_domain(context, params)
      with_response(context) do |query_params|
        domain = params["domain"]
        confirmation = query_params["confirmation"]?.try &.to_i || 1
        address = convert_domain_to_address(domain, confirmation)
        @blockchain.utxo.amount_impl(address, "all", confirmation)
      end
    end

    def __v1_domain_token(context, params)
      with_response(context) do |query_params|
        domain = params["domain"]
        token = params["token"]
        confirmation = query_params["confirmation"]?.try &.to_i || 1
        address = convert_domain_to_address(domain, confirmation)
        @blockchain.utxo.amount_impl(address, token, confirmation)
      end
    end

    def __v1_scars_sales(context, params)
      with_response(context) do
        @blockchain.scars.scars_for_sale_impl
      end
    end

    def __v1_scars(context, params)
      domain = params["domain"]

      with_response(context) do |query_params|
        confirmation = query_params["confirmation"]?.try &.to_i || 1
        @blockchain.scars.scars_resolve_impl(domain, confirmation)
      end
    end

    def __v1_tokens(context, params)
      with_response(context) do
        @blockchain.token.tokens_list_impl
      end
    end

    def __v1_nodes(context, params)
      with_response(context) do
        @blockchain.node_info.nodes_impl
      end
    end

    def __v1_node(context, params)
      with_response(context) do
        @blockchain.node_info.node_impl
      end
    end

    def __v1_node_id(context, params)
      id = params["id"]

      with_response(context) do
        @blockchain.node_info.node_id_impl(id)
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

    private def convert_domain_to_address(domain : String, confirmation : Int32) : String
      resolved = @blockchain.scars.scars_resolve_impl(domain, confirmation)
      raise "the domain #{domain} is not resolved" unless resolved[:resolved]

      resolved[:domain][:address]
    end

    include Router
    include NodeComponents::APIFormat
    include TransactionModels
  end
end
