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

require "../cli"

module ::Axentro::Interface::Axem
  class Root < CLI
    def sub_actions
      [] of AxeAction
    end

    def option_parser
      G.op.create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
        Options::IS_TESTNET,
        Options::PROCESSES,
        Options::CONFIG_NAME,
      ])
    end

    def run_impl(action_name)
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node

      node_uri = URI.parse(node)
      use_ssl = (node_uri.scheme == "https")

      puts_help(HELP_CONNECTING_NODE) unless host = node_uri.host
      puts_help(HELP_CONNECTING_NODE) unless port = node_uri.port

      wallet = get_wallet(wallet_path, G.op.__wallet_password)
      wallet_is_testnet = (Core::Wallet.address_network_type(wallet.address)[:name] == "testnet")

      raise "wallet type mismatch" if G.op.__is_testnet != wallet_is_testnet

      miner = Core::Miner.new(G.op.__is_testnet, host, port, wallet, G.op.__processes, use_ssl)
      miner.run
    end
  end
end

include ::Axentro::Interface
include Axentro::Core::Keys

::Axentro::Interface::Axem::Root.new(
  {name: "axem", desc: "Axentro mining process"}, [] of AxeAction
).run
