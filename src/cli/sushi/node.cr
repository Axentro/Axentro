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
  class Node < CLI
    def sub_actions
      [
        {
          name: "nodes",
          desc: "show all connected nodes to the connecting node",
        },
        {
          name: "node",
          desc: "show the specified node (connecting node by default)",
        },
      ]
    end

    def option_parser
      create_option_parser([
                             Options::CONNECT_NODE,
                             Options::JSON,
                             Options::NODE_ID,
                           ])
    end

    def run_impl(action_name)
      case action_name
      when "nodes"
        return nodes
      when "node"
        return node
      end

      specify_sub_action!(action_name)
    rescue e : Exception
      puts_error e.message
    end

    def nodes
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node

      payload = {call: "nodes"}.to_json

      body = rpc(node, payload)

      unless __json
        json = JSON.parse(body)

        puts_success("Show the connected node")

        puts_info("--- successor list")

        successor_list = json["successor_list"].as_a
        successor_list.each_with_index do |successor, i|
          puts_info("#{i} #{successor}")
        end

        puts_info("--- predecessor")

        if predecessor = json["predecessor"]?
          puts_info("#{predecessor}")
        end

        puts_info("--- private nodes")

        private_nodes = json["private_nodes"].as_a
        private_nodes.each_with_index do |private_node, i|
          puts_info("#{i} #{private_node}")
        end
      else
        puts body
      end
    end

    def node
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node

      payload = if node_id = __node_id
                  {call: "node_id", id: node_id}.to_json
                else
                  {call: "node"}.to_json
                end

      body = rpc(node, payload)

      unless __json
        puts body
      else
        puts body
      end
    end

    # todo
    # def puts_node_context(node_context : JSON::Any)

    include GlobalOptionParser
  end
end
