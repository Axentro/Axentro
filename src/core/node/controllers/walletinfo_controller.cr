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
  struct WalletMessage
    include JSON::Serializable
    property address : String
  end

  class WalletInfoController
    @sockets : Array(HTTP::WebSocket) = [] of HTTP::WebSocket
    @socket_address : Hash(String, HTTP::WebSocket) = {} of String => HTTP::WebSocket

    def initialize(@blockchain : Blockchain)
    end

    def wallet_info(socket : HTTP::WebSocket)
      socket.on_close do |_|
        @sockets.delete(socket)
        @socket_address.each do |a, s|
          if s == socket
            @socket_address.delete(a)
            break
          end
        end
        debug "a wallet info subscriber disconnected (#{@sockets.size})"
      end

      @sockets << socket
      debug "new wallet info subscriber coming (#{@sockets.size})"

      socket.on_message do |message|
        begin
          wallet_message = WalletMessage.from_json(message)
          address = get_address(wallet_message.address)
          @socket_address[address] = socket
          socket.send(@blockchain.wallet_info.wallet_info_impl(address).to_json)
        rescue
          socket.send({message: "could not process message: #{message}"}.to_json)
        end
      end
    end

    def update_wallet_information(transactions)
      debug "broadcast to the subscribers (#{@sockets.size})"

      senders = transactions.flat_map { |t| t.senders.map(&.address) }
      recipients = transactions.flat_map { |t| t.recipients.map(&.address) }
      addresses = (senders + recipients).uniq

      addresses.each do |address|
        address = get_address(address)
        _socket = @socket_address[address]?
        if _socket
          data = @blockchain.wallet_info.wallet_info_impl(address).to_json
          _socket.send(data)
        end
      rescue e : Exception
        debug "an error (#{e})"
      end
    end

    private def get_address(maybe_address)
      address_or_domain = maybe_address
      address = address_or_domain
      if address.ends_with?(".ax")
        domain_name = address_or_domain
        result = @blockchain.database.get_domain_map_for(domain_name)[domain_name]?
        if result
          address = result[:address]
        end
      end
      address
    end

    def get_handler
      WebSocketHandler.new("/wallet_info") { |socket, _| wallet_info(socket) }
    end

    include Logger
  end
end
