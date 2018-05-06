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
  class Pubsub < CLI
    def sub_actions
      [] of SushiAction
    end

    def option_parser
      create_option_parser([
        Options::CONNECT_NODE,
        Options::JSON,
      ])
    end

    def puts_line
      puts "+#{"-" * 22}+#{"-" * 66}|"
    end

    def puts_line(name, value)
      puts "| %20s | %64s |" % [name, value]
    end

    def run_impl(action_name)
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node

      node_uri = URI.parse(node)
      use_ssl = (node_uri.scheme == "https")

      socket = HTTP::WebSocket.new(node_uri.host.not_nil!, "/pubsub", node_uri.port.not_nil!, use_ssl)
      socket.on_message do |message|
        if __json
          puts message
        else
          block = Core::Block.from_json(message)

          puts_line
          puts_line("index", block.index)
          puts_line("nonce", block.nonce)
          puts_line("prev_hash", block.prev_hash)
          puts_line("merkle_tree_root", block.merkle_tree_root)
          puts_line
        end
      end

      puts_success "Start listening new blocks..." unless __json

      socket.run
    end

    include GlobalOptionParser
  end
end
