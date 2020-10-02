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
  abstract class Controller
    def initialize(@blockchain : Blockchain)
    end

    def node
      @blockchain.node
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
        context.response.print api_error(error_message)
      else
        context.response.status_code = 500
      end

      context
    end

    def exec_get(context, params) : HTTP::Server::Context
      exec_internal_get(context, params)
    end

    def exec_post(context, params) : HTTP::Server::Context
      raise "empty body" unless body = context.request.body
      raise "empty payload" unless payload = body.gets

      json = JSON.parse(payload)

      exec_internal_post(json, context, params)
    end

    def unpermitted_method(context) : HTTP::Server::Context
      context.response.status_code = 403
      context.response.print api_error("unpermitted method: #{context.request.method}")
      context
    end

    abstract def exec_internal_get(context, params) : HTTP::Server::Context
    abstract def exec_internal_post(json, context, params) : HTTP::Server::Context

    include NodeComponents::APIFormat
  end
end

require "./controllers/*"
