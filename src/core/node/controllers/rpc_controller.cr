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

module ::Axentro::Core::Controllers
  class RPCController < Controller
    def exec_internal_post(json, context, params) : HTTP::Server::Context
      call = json["call"].to_s

      @blockchain.dapps.each do |dapp|
        # pp dapp.transaction_actions
        next unless result_context = dapp.define_rpc?(call, json, context, params)
        return result_context
      end

      unpermitted_call(call, context)
    end

    def exec_internal_get(context, params) : HTTP::Server::Context
      unpermitted_method(context)
    end

    def unpermitted_call(call, context) : HTTP::Server::Context
      context.response.status_code = 403
      context.response.print api_error("unpermitted call: #{call}")
      context
    end

    def get_handler
      options "/rpc" do |context|
        context.response.headers["Allow"] = "HEAD,GET,PUT,POST,DELETE,OPTIONS"
        context.response.headers["Access-Control-Allow-Origin"] = "*"
        context.response.headers["Access-Control-Allow-Headers"] =
          "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept"
        context.response.status_code = 200
        context.response.print ""
        context
      end

      post "/rpc" do |context, params|
        context.response.headers["Access-Control-Allow-Origin"] = "*"
        exec(context, params)
      end

      route_handler
    end

    include Router
  end
end
