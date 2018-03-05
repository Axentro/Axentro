require "../cli"

module ::Sushi::Interface::SushiM
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
        Options::THREADS,
      ])
    end

    def run_impl(action_name)
      puts_help(HELP_WALLET_PATH) unless wallet_path = __wallet_path
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node

      node_uri = URI.parse(node)
      use_ssl = (node_uri.scheme == "https")

      puts_help(HELP_CONNECTING_NODE) unless host = node_uri.host
      puts_help(HELP_CONNECTING_NODE) unless port = node_uri.port

      wallet = get_wallet(wallet_path, __wallet_password)
      wallet_is_testnet = (Core::Wallet.address_network_type(wallet.address)[:name] == "testnet")

      raise "wallet type mismatch" if __is_testnet != wallet_is_testnet

      miner = Core::Miner.new(__is_testnet, host, port, wallet, __threads, use_ssl)
      miner.run
    end

    include GlobalOptionParser
  end
end

include ::Sushi::Interface
include Sushi::Core::Keys

::Sushi::Interface::SushiM::Root.new(
  {name: "sushim", desc: "sushi's mining process"}, [] of SushiAction
).run
