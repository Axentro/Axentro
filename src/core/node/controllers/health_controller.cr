module ::Sushi::Core::Controllers
  class HealthController < Controller
    def exec_internal_get(context, params) : HTTP::Server::Context
      context.response.status_code == 200
      context
    end

    def exec_internal_post(json, context, params) : HTTP::Server::Context
      unpermitted_method(context)
    end
  end
end
