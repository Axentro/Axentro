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

module ::Sushi::Core::DApps::BuildIn
  class NodeInfo < DApp
    def setup
    end

    def transaction_actions : Array(String)
      [] of String
    end

    def transaction_related?(action : String) : Bool
      false
    end

    def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      true
    end

    def record(chain : Blockchain::Chain)
    end

    def clear
    end

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
      case call
      when "nodes"
        return nodes(json, context, params)
      when "node"
        return node(json, context, params)
      when "node_id"
        return node_id(json, context, params)
      end

      nil
    end

    def nodes(json, context, params)
      context.response.print api_success(nodes_impl)
      context
    end

    def nodes_impl
      node.chord.connected_nodes
    end

    def node(json, context, params)
      context.response.print api_success(node_impl)
      context
    end

    def node_impl
      node.chord.context
    end

    def node_id(json, context, params)
      id = json["id"].as_s

      context.response.print api_success(node_id_impl(id))
      context
    end

    def node_id_impl(id : String)
      node.chord.find_node(id)
    end

    def on_message(action : String, from_address : String, content : String, from = nil)
      false
    end
  end
end
