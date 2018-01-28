module ::Sushi::Core::Controllers
  abstract class Controller
    def initialize(@blockchain : Blockchain)
    end

    def set_node(@node : Node)
    end

    def node
      @node.not_nil!
    end

    def exec(context, params) : HTTP::Server::Context
      case context.request.method
      when "GET"
        return exec_get(context, params)
      when "POST"
        return exec_post(context, params)
      end

      unpermitted_method(context)
    rescue e : Exception
      if error_message = e.message
        context.response.status_code = 403
        context.response.print error_message
      else
        context.response.status_code = 500
      end

      context
    end

    def exec_get(context, params) : HTTP::Server::Context
      exec_internal_get(context, params)
    end

    def exec_post(context, params) : HTTP::Server::Context
      raise "Empty body" unless body = context.request.body
      raise "Empty payload" unless payload = body.gets

      json = JSON.parse(payload)

      exec_internal_post(json, context, params)
    end

    def unpermitted_method(context) : HTTP::Server::Context
      context.response.status_code = 403
      context.response.print "Unpermitted method: #{context.request.method}"
      context
    end

    abstract def exec_internal_get(context, params) : HTTP::Server::Context
    abstract def exec_internal_post(json, context, params) : HTTP::Server::Context

    include Common::Num
  end
end

require "./controllers/*"
