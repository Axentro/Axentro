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
  class PubsubController
    @sockets : Array(HTTP::WebSocket) = [] of HTTP::WebSocket

    def initialize(@blockchain : Blockchain)
    end

    def pubsub(socket : HTTP::WebSocket)
      socket.on_close do |_|
        @sockets.delete(socket)
        debug "a pubsub subscriber disconnected (#{@sockets.size})"
      end

      @sockets << socket
      debug "new pubsub subscriber coming (#{@sockets.size})"

      socket.send(@blockchain.latest_block.to_json)
    end

    def broadcast_latest_block
      debug "broadcast to the subscribers (#{@sockets.size})"

      @sockets.each do |socket|
        socket.send(@blockchain.latest_block.to_json)
      rescue e : Exception
        @sockets.delete(socket)
        debug "a pubsub subscriber disconnected (#{@sockets.size})"
      end
    end

    def get_handler
      WebSocketHandler.new("/pubsub") { |socket, _| pubsub(socket) }
    end

    include Logger
  end
end
