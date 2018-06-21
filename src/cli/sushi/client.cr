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

      socket = HTTP::WebSocket.new(node_uri.host.not_nil!, "/peer", node_uri.port.not_nil!, use_ssl)
      socket.on_message do |message|
        p message
      end

      puts_success "start client for sushi..."

      content = {address: nil}.to_json

      socket.send({type: M_TYPE_CLIENT_HANDSHAKE, content: content}.to_json)
      socket.run
    end

    include Core::Protocol
    include GlobalOptionParser
  end
end
