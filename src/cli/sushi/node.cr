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

        puts_success ""
        puts_success "show the connected node"
        puts_success ""

        puts_title

        json["successor_list"].each_with_index do |successor, i|
          puts_node_context("successor (#{i})", node_context(successor))
          puts_line if i == 0
        end

        if predecessor = json["predecessor"]?
          puts_node_context("predecessor", node_context(predecessor))
          puts_line
        end

        json["private_nodes"].each_with_index do |private_node, i|
          puts_node_context("private node (#{i})", node_context(private_node))
          puts_line if i == 0
        end

        puts_info ""
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
        json = JSON.parse(body)

        puts_success ""
        puts_success "show the node"
        puts_success ""

        puts_title

        puts_node_context("-", node_context(json))

        puts_line

        puts_info ""
      else
        puts body
      end
    end

    def puts_title
      puts_line
      puts_info "| %20s | %32s | %30s | %10s |" % ["role", "id", "remote", "private?"]
      puts_line
    end

    def puts_line
      puts_info "+-%20s-+-%32s-+-%30s-+-%10s-|" % ["-" * 20, "-" * 32, "-" * 30, "-" * 10]
    end

    def puts_node_context(role : String, node_context)
      puts_info "| %20s | %32s | %30s | %10s |" % [
        role,
        node_context[:id],
        node_context[:port] != -1 ? "#{node_context[:host]}:#{node_context[:port]}" : "-",
        node_context[:is_private],
      ]
    end

    def node_context(json)
      {
        id:         json["id"].as_s,
        host:       json["host"].as_s,
        port:       json["port"].as_i,
        ssl:        json["ssl"].as_bool,
        type:       json["type"].as_s,
        is_private: json["is_private"].as_bool,
      }
    end

    include GlobalOptionParser
  end
end
