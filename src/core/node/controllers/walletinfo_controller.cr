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
    class WalletInfoController
      @sockets : Array(HTTP::WebSocket) = [] of HTTP::WebSocket
  
      def initialize(@blockchain : Blockchain)
      end
  
      def wallet_info(socket : HTTP::WebSocket)
        socket.on_close do |_|
          @sockets.delete(socket)
          debug "a wallet info subscriber disconnected (#{@sockets.size})"
        end

        # 1. accept a socket connection from client
        # 2. check the message from the client to see which address they are interested in
        #    - can be address or domain
        #  {"address": "fadsfafafff"} or {"domain": "adfdasfsfs"}
        #
        # 3. decode json and add the socket + address/domain to a collection of socket_addresses if all ok
        # 4. send the wallet_info back to the socket client
  
        @sockets << socket
        debug "new wallet info subscriber coming (#{@sockets.size})"
  
        # TODO - send latest wallet information
             
        socket.send(@blockchain.latest_block.to_json)
      end
  
      # TODO - send latest wallet information when a new block is created - using the socket_addresses 
      def broadcast_latest_block
        debug "broadcast to the subscribers (#{@sockets.size})"
  
        @sockets.each do |socket|
          socket.send(@blockchain.latest_block.to_json)
        rescue e : Exception
          @sockets.delete(socket)
          debug "a wallet info subscriber disconnected (#{@sockets.size})"
        end
      end
  
      def get_handler
        WebSocketHandler.new("/wallet_info") { |socket, _| wallet_info(socket) }
      end
  
      include Logger
    end
  end
  