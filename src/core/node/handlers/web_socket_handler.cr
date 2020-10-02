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

module ::Axentro::Core
  class WebSocketHandler < HTTP::WebSocketHandler
    def initialize(@path : String, &@proc : HTTP::WebSocket, HTTP::Server::Context -> Void)
    end

    def call(context : HTTP::Server::Context)
      if context.request.path == @path
        super(context)
      else
        call_next(context)
      end
    end
  end
end
