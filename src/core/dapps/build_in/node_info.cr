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

module ::Axentro::Core::DApps::BuildIn
  class NodeInfo < DApp
    def setup
    end

    def transaction_actions : Array(String)
      [] of String
    end

    def transaction_related?(action : String) : Bool
      false
    end

    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      ValidatedTransactions.empty
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
      when "node_address"
        return node_address(json, context, params)
      when "official_nodes"
        return official_nodes(json, context, params)
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

    def node_address(json, context, params)
      address = json["address"].as_s

      context.response.print api_success(node_address_impl(address))
      context
    end

    def official_nodes(json, context, params)
      context.response.print api_success(official_nodes_impl)
      context
    end

    def node_id_impl(id : String)
      node.chord.find_node(id)
    end

    def node_address_impl(address : String)
      node.chord.find_node_by_address(address)
    end

    def official_nodes_impl
      node.chord.official_nodes_list
    end

    def on_message(action : String, from_address : String, content : String, from = nil)
      false
    end
  end
end
