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

module ::Sushi::Interface::Sushi
  class Client < CLI

    @client_id : String?
    @socket : HTTP::WebSocket?

    def sub_actions
      [] of SushiAction
    end

    def option_parser
      create_option_parser([
        Options::CONNECT_NODE,
        Options::CONFIG_NAME,
      ])
    end

    def run_impl(action_name)
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node

      node_uri = URI.parse(node)
      use_ssl = (node_uri.scheme == "https")

      @socket = HTTP::WebSocket.new(node_uri.host.not_nil!, "/peer", node_uri.port.not_nil!, use_ssl)

      socket.on_message do |message|
        message_json = JSON.parse(message)
        message_type = message_json["type"].as_i
        message_content = message_json["content"].as_s

        case message_type
        when M_TYPE_CLIENT_HANDSHAKE_ACCEPTED
          _handshake_accepted(message_content)
        when M_TYPE_CLIENT_RECEIVE_MESSAGE
          _receive_message(message_content)
        else
          puts ""
          puts "  received unknown message type #{red(message_type)}"
          puts ""
        end
      end

      puts ""
      puts_success "  start client for sushi..."

      content = {address: nil}.to_json

      socket.send({type: M_TYPE_CLIENT_HANDSHAKE, content: content}.to_json)

      spawn do
        socket.run
      rescue e : Exception
        puts_error "dissconnected. exit with -1"
        exit -1
      end

      sleep
    end

    def socket : HTTP::WebSocket
      @socket.not_nil!
    end

    def _handshake_accepted(_content : String)
      _m_content = M_CONTENT_CLIENT_HANDSHAKE_ACCEPTED.from_json(_content)

      @client_id = _m_content.id

      puts ""
      puts_success "  successfully connected to the node!"
      puts_success "  your client id is #{@client_id}"
      puts ""

      gets_loop
    end

    def _receive_message(_content : String)
      _m_content = M_CONTENT_CLIENT_RECEIVE_MESSAGE.from_json(_content)

      from_id = _m_content.from_id
      to_id = _m_content.to_id
      message = _m_content.message

      puts ""
      puts "  received message from #{light_green(from_id)}"
      puts ""
      puts "```"
      puts "#{message}"
      puts "```"
      puts ""
    end

    def gets_loop
      while show_cursor && (input = STDIN.gets)
        send_command(input)
      end
    end

    def show_cursor : Bool
      print "> "
      true
    end

    def send_command(input : String)
      command = input.split(" ", 2)[0]

      case command
      when "send"
        send(input)
      when "help"
        show_help
      else
        puts ""
        puts "  unknown command #{yellow(command)} (will be ignored.)"
        puts "  input `> help` to show available commands"
        puts ""
      end

    rescue e : Exception
      puts ""
      puts "  #{red("error happens!")}"
      puts "  the reason is '#{red(e.message)}'."
      puts "  input `> help` to show available commands"
      puts ""
    end

    def send(input : String)
      unless input =~ /^send\s(.+?)\s(.+)$/
        raise "make sure you input `> send [client_id] [message]`"
      end

      to_id = $1.to_s
      message = $2.to_s

      puts ""
      puts "send a message (#{light_green(message[0..9])}#{message.size > 10 ? "..." : ""}) to #{light_green(to_id)}"
      puts ""

      raise "client id is unknown" unless from_id = @client_id

      content = {
        from_id: from_id,
        to_id: to_id,
        message: message,
      }.to_json

      socket.send({type: M_TYPE_CLIENT_SEND_MESSAGE, content: content}.to_json)
    end

    def show_help
      puts ""
      puts "  available commands"
      puts ""
      puts "  - send [client_id] [message]"
      puts "    send a message for the client_id"
      puts ""
      puts "  - help"
      puts "    show this help"
      puts ""
    end

    include Core::Protocol
    include GlobalOptionParser
  end
end
