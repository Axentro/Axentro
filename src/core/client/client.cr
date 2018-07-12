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

module ::Sushi::Core
  class Client < HandleSocket
    @client_id : String?
    @socket : HTTP::WebSocket?

    def initialize(@host : String, @port : Int32, @use_ssl : Bool, @wallet : Wallet)
    end

    def run
      @socket = HTTP::WebSocket.new(@host, "/peer", @port, @use_ssl)

      socket.on_message do |message|
        message_json = JSON.parse(message)
        message_type = message_json["type"].as_i
        message_content = message_json["content"].as_s

        case message_type
        when M_TYPE_CLIENT_HANDSHAKE_ACCEPTED
          _handshake_accepted(message_content)
        when M_TYPE_CLIENT_RECEIVE
          _receive_message(message_content)
        else
          puts ""
          puts "  received unknown message type #{red(message_type)}"
          puts ""
        end
      end

      socket.on_close do |_|
        disconnected
      end

      puts ""
      puts light_green("  start client for sushi...")

      send(socket, M_TYPE_CLIENT_HANDSHAKE, {address: @wallet.address})

      spawn do
        socket.run
      rescue e : Exception
        clean_connection(socket)
      end
    end

    def socket : HTTP::WebSocket
      @socket.not_nil!
    end

    def _handshake_accepted(_content : String)
      _m_content = M_CONTENT_CLIENT_HANDSHAKE_ACCEPTED.from_json(_content)

      @client_id = _m_content.id

      puts ""
      puts light_green("  successfully connected to the node!")
      puts light_green("  your client id is #{@client_id}")
      puts ""

      show_cursor
    end

    def _receive_message(_content : String)
      _m_content = M_CONTENT_CLIENT_RECEIVE.from_json(_content)

      from_id = _m_content.from_id
      to_id = _m_content.to_id
      content = _m_content.content

      if from_id != to_id
        puts ""
        puts "  received message from #{light_green(from_id)}"
        puts ""
      end

      puts ""
      puts ""
      puts "```"
      puts "#{content}"
      puts "```"
      puts ""

      show_cursor
    end

    def message(to_id : String, message : String)
      raise "client id is unknown" unless from_id = @client_id

      content = {to_id: to_id, message: message}.to_json
      create_content("message", from_id, content)

      show_cursor
    end

    def fee
      raise "client id is unknown" unless from_id = @client_id

      content = ""
      create_content("fee", from_id, content)

      show_cursor
    end

    def create_content(action : String, from_id : String, content : String)
      content = {action: action, from_id: from_id, content: content}
      send(socket, M_TYPE_CLIENT_CONTENT, content)
    end

    def clean_connection(socket)
      disconnected
    end

    def disconnected
      puts red("dissconnected. exit with -1")
      exit -1
    end

    def show_cursor
      print "> "
    end

    include Protocol
    include Common::Color
  end
end
