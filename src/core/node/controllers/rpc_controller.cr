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
  class RPCController < Controller
    def exec_internal_post(json, context, params) : HTTP::Server::Context
      call = json["call"].to_s

      @blockchain.dapps.each do |dapp|
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
      context.response.print "unpermitted call: #{call}"
      context
    end
  end
end
