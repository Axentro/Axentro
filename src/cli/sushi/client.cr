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
    @client : Core::Client?

    def sub_actions
      [] of SushiAction
    end

    def option_parser
      create_option_parser([
        Options::CONNECT_NODE,
        Options::CONFIG_NAME,
      ])
    end

    def client : Core::Client
      @client.not_nil!
    end

    def run_impl(action_name)
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node

      node_uri = URI.parse(node)
      use_ssl = (node_uri.scheme == "https")

      @client = Core::Client.new(node_uri.host.not_nil!, node_uri.port.not_nil!, use_ssl)

      client.run

      gets_command
    end

    def gets_command
      while input = STDIN.gets
        send_command(input)
      end
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
      message_print = light_green(message[0..9]) + (message.size > 10 ? "..." : "")

      puts ""
      puts "send a message \"#{message_print}\" to #{light_green(to_id)}"
      puts ""

      client.send_message(to_id, message)
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
