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
require "../core/developer_fund/*"
require "../core/official_nodes"

module ::Axentro::Interface::Axen
  class Root < CLI
    def sub_actions
      [] of AxeAction
    end

    def option_parser : OptionParser | Nil
      G.op.create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
        Options::IS_TESTNET,
        Options::IS_PRIVATE,
        Options::BIND_HOST,
        Options::BIND_PORT,
        Options::PUBLIC_URL,
        Options::DATABASE_PATH,
        Options::CONFIG_NAME,
        Options::DEVELOPER_FUND,
        Options::FASTNODE_ADDRESS,
        Options::SECURITY_LEVEL_PERCENTAGE,
        Options::MAX_MINERS,
        Options::MAX_PRIVATE_NODES,
        Options::OFFICIAL_NODES,
        Options::EXIT_IF_UNOFFICIAL,
        Options::SYNC_CHUNK_SIZE,
        Options::RECORD_NONCES,
      ])
    end

    private def get_connecting_port(use_ssl : Bool)
      if connect_node = G.op.__connect_node
        connect_uri = URI.parse(connect_node)
        if use_ssl
          connect_uri.port || 443
        else
          connect_uri.port || 80
        end
      end
    end

    def run_impl(action_name)
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path

      unless G.op.__is_private
        puts_help(HELP_PUBLIC_URL) unless public_url = G.op.__public_url

        public_uri = URI.parse(public_url)

        puts_help(HELP_PUBLIC_URL) unless public_host = public_uri.host
        puts_help(HELP_PUBLIC_URL) unless public_port = public_uri.port

        ssl = (public_uri.scheme == "https")
      end

      has_first_connection = false
      use_ssl = false

      if connect_node = G.op.__connect_node
        connect_uri = URI.parse(connect_node)
        use_ssl = (connect_uri.scheme == "https")
        has_first_connection = !connect_uri.host.nil?
      end

      wallet = get_wallet(wallet_path, G.op.__wallet_password)

      database = if database_path = G.op.__database_path
                   Core::Database.new(database_path)
                 else
                   raise "A database is required for node startup (use -d option)"
                 end

      developer_fund = G.op.__developer_fund
      official_nodes = G.op.__official_nodes

      security_level_percentage = G.op.__security_level_percentage
      sync_chunk_size = G.op.__sync_chunk_size

      max_miners = G.op.__max_miners
      max_nodes = G.op.__max_nodes
      record_nonces = G.op.__record_nonces

      connection_port = get_connecting_port(use_ssl)

      node = if has_first_connection
               Core::Node.new(G.op.__is_private, G.op.__is_testnet, G.op.__bind_host, G.op.__bind_port, public_host, public_port, ssl, connect_uri.not_nil!.host, connection_port, wallet, database_path, database, developer_fund, official_nodes, G.op.__exit_if_unofficial, security_level_percentage, sync_chunk_size, record_nonces, max_miners, max_nodes, use_ssl)
             else
               Core::Node.new(G.op.__is_private, G.op.__is_testnet, G.op.__bind_host, G.op.__bind_port, public_host, public_port, ssl, nil, nil, wallet, database_path, database, developer_fund, official_nodes, G.op.__exit_if_unofficial, security_level_percentage, sync_chunk_size, record_nonces, max_miners, max_nodes, use_ssl)
             end
      node.run!
    end

    include Core::Protocol
    include Logger
  end
end

include ::Axentro::Interface
include Axentro::Core::Keys

::Axentro::Interface::Axen::Root.new(
  {name: "axen", desc: "Axentro node"}, [] of AxeAction
).run
