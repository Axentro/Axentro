module ::Sushi::Core::Controllers
  class RPCController < Controller
    def exec_internal_post(json, context, params) : HTTP::Server::Context
      call = json["call"].to_s

      @blockchain.dapps.each do |dapp|
        next unless result_context = dapp.rpc?(call, json, context, params)
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
