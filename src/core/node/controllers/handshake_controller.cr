module ::Sushi::Core::Controllers
  class HandshakeController < Controller
    def exec_internal_get(context, params) : HTTP::Server::Context
      connection_hash = sha256(params["salt"] + node.id)
      context.response.status_code = 200
      context.response.print connection_hash
      context
    end

    def exec_internal_post(json, context, params) : HTTP::Server::Context
      unpermitted_method(context)
    end

    include Hashes
  end
end
