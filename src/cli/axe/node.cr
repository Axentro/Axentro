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

module ::Axentro::Interface::Axe
  class Node < CLI
    def sub_actions : Array(AxeAction)
      [
        {
          name: I18n.translate("axe.cli.node.nodes.title"),
          desc: I18n.translate("axe.cli.node.nodes.desc"),
        },
        {
          name: I18n.translate("axe.cli.node.node.title"),
          desc: I18n.translate("axe.cli.node.node.desc"),
        },
        {
          name: I18n.translate("axe.cli.node.official.title"),
          desc: I18n.translate("axe.cli.node.official.desc"),
        },
      ]
    end

    def option_parser : OptionParser?
      G.op.create_option_parser([
        Options::CONNECT_NODE,
        Options::JSON,
        Options::NODE_ID,
      ])
    end

    def run_impl(action_name) : OptionParser?
      case action_name
      when I18n.translate("axe.cli.node.nodes.title")
        return nodes
      when I18n.translate("axe.cli.node.node.title")
        return node
      when I18n.translate("axe.cli.node.official.title")
        return official_nodes
      end

      specify_sub_action!(action_name)
    rescue e : Exception
      puts_error e.message
    end

    def nodes
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node

      payload = {call: "nodes"}.to_json

      body = rpc(node, payload)

      if G.op.__json
        puts body
      else
        json = JSON.parse(body)

        successors = multi_node_data(json["successor_list"].as_a, "successor")
        privates = multi_node_data(json["successor_list"].as_a, "private")
        all_nodes = multi_node_data(json["finger_table"].as_a, "")

        table = Tallboy.table do
          columns do
            add "kind"
            add "id"
            add "host"
            add "port"
            add "network"
            add "address"
            add "private?"
          end
          header "#{green("showing connected nodes")}"
          header
          rows successors
          if predecessor = json["predecessor"]?
            row single_node_json_data(predecessor, "predecessor")
          end
          rows privates
        end

        table2 = Tallboy.table do
          columns do
            add "kind"
            add "id"
            add "host"
            add "port"
            add "network"
            add "address"
            add "private?"
          end
          header "#{green("showing all connected nodes on the network")}"
          header
          rows all_nodes
        end

        puts table.render
        puts table2.render
      end
    end

    private def single_node_json_data(json, kind = "")
      [kind, json["id"].as_s, json["host"].as_s, json["port"].as_i, json["type"].as_s, json["address"].as_s, json["is_private"].as_bool]
    end

    private def single_node_map_data(d, kind = "")
      [kind, d["id"], d["host"], d["port"], d["type"], d["address"], d["is_private"]]
    end

    private def multi_node_data(data_array, kind)
      data_array.map { |d| single_node_map_data(d, kind) }
    end

    def node
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node

      payload = if node_id = G.op.__node_id
                  {call: "node_id", id: node_id}.to_json
                else
                  {call: "node"}.to_json
                end

      body = rpc(node, payload)

      if G.op.__json
        puts body
      else
        json = JSON.parse(body)

        table = Tallboy.table do
          columns do
            add "id"
            add "host"
            add "port"
            add "network"
            add "address"
            add "private?"
          end
          header "#{green("showing information about this node")}"
          header
          rows [[json["id"].as_s, json["host"].as_s, json["port"].as_i, json["type"].as_s, json["address"].as_s, json["is_private"].as_bool]]
        end

        puts table.render
      end
    end

    def official_nodes
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node

      payload = {call: "official_nodes"}.to_json

      body = rpc(node, payload)

      if G.op.__json
        puts body
      else
        json = JSON.parse(body)

        table = Tallboy.table do
          columns do
            add "id"
            add "address"
            add "url"
          end
          header "#{green("all official node addresses")}"
          header json["all"].as_a.join("\n")
          header "#{green("online official nodes")}"
          header
          rows json["online"].as_a.map { |n| [n["id"], n["address"], n["url"]] }
        end

        puts table.render
      end
    end
  end
end
