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

require "../cli"

module ::Sushi::Interface::SushiD
  class Root < CLI
    def sub_actions
      [] of SushiAction
    end

    def option_parser
      create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
        Options::IS_TESTNET,
        Options::IS_PRIVATE,
        Options::BIND_HOST,
        Options::BIND_PORT,
        Options::PUBLIC_URL,
        Options::DATABASE_PATH,
      ])
    end

    def run_impl(action_name)
      puts_help(HELP_WALLET_PATH) unless wallet_path = __wallet_path

      unless __is_private
        puts_help(HELP_PUBLIC_URL) unless public_url = __public_url

        public_uri = URI.parse(public_url)

        puts_help(HELP_PUBLIC_URL) unless public_host = public_uri.host
        puts_help(HELP_PUBLIC_URL) unless public_port = public_uri.port

        ssl = (public_uri.scheme == "https")
      end

      has_first_connection = false
      use_ssl = false

      if connect_node = __connect_node
        connect_uri = URI.parse(connect_node)
        use_ssl = (connect_uri.scheme == "https")
        has_first_connection = !connect_uri.host.nil? && !connect_uri.port.nil?
      end

      wallet = get_wallet(wallet_path, __wallet_password)

      database = if database_path = __database_path
                   Core::Database.new(database_path)
                 else
                   nil
                 end

      node = if has_first_connection
               Core::Node.new(__is_private, __is_testnet, __bind_host, __bind_port, public_host, public_port, ssl, connect_uri.not_nil!.host, connect_uri.not_nil!.port, wallet, database, use_ssl)
             else
               Core::Node.new(__is_private, __is_testnet, __bind_host, __bind_port, public_host, public_port, ssl, nil, nil, wallet, database, use_ssl)
             end
      node.run!
    end

    include Core::Protocol
    include Logger
    include GlobalOptionParser
  end
end

include ::Sushi::Interface
include Sushi::Core::Keys

::Sushi::Interface::SushiD::Root.new(
  {name: "sushid", desc: "sushi's node"}, [] of SushiAction
).run
