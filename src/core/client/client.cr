# Copyright © 2017-2018 The Axentro Core developers
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
  class Client < HandleSocket
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
        when M_TYPE_CLIENT_SALT
          _salt(message_content)
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
      puts light_green("  starting client for axentro...")

      send(socket, M_TYPE_CLIENT_HANDSHAKE, {public_key: @wallet.public_key})

      spawn do
        socket.run
      rescue e : Exception
        clean_connection(socket)
      end
    end

    def socket : HTTP::WebSocket
      @socket.not_nil!
    end

    def _salt(_content : String)
      _m_content = MContentClientSalt.from_json(_content)

      private_key = Core::Keys::Wif.new(@wallet.wif).private_key

      signature = KeyUtils.sign(private_key.as_hex, _m_content.salt)

      send(socket, M_TYPE_CLIENT_UPGRADE, {
        address:    @wallet.address,
        public_key: @wallet.public_key,
        signature:  signature,
      })
    end

    def _handshake_accepted(_content : String)
      MContentClientHandshakeAccepted.from_json(_content)

      puts ""
      puts light_green("  successfully connected to the node!")
      puts ""

      show_cursor
    end

    def _receive_message(_content : String)
      _m_content = MContentClientReceive.from_json(_content)

      from = _m_content.from
      to = _m_content.to
      content = _m_content.content

      if from != to
        puts ""
        puts ""
        puts "  received message from #{light_green(from[0..7] + "...")}"
        puts ""
      end

      puts ""
      puts "```"
      puts "#{content}"
      puts "```"
      puts ""

      show_cursor
    end

    def message(to : String, message : String)
      content = {to: to, message: message}.to_json
      create_content("message", content)

      show_cursor
    end

    def amount(token : String)
      content = {token: token}.to_json
      create_content("amount", content)

      show_cursor
    end

    def fee
      content = ""
      create_content("fee", content)

      show_cursor
    end

    def create_content(action : String, content : String)
      content = {action: action, from: from, content: content}
      send(socket, M_TYPE_CLIENT_CONTENT, content)
    end

    def clean_connection(socket)
      disconnected
    end

    def disconnected
      puts red("disconnected. exited with -1.")
      exit -1
    end

    def show_cursor
      print "> "
    end

    def from : String
      @wallet.address
    end

    include Protocol
    include Common::Color
  end
end
