module ::Garnet::Interface
  class Start < CLI
    @wallet_path : String?
    @node        : String?
    @is_testnet  : Bool = false

    def sub_actions
      [] of GarnetAction
    end

    def option_parser
      OptionParser.new do |parser|
        parser.on("-w WALLET_PATH", "--wallet-path=WALLET_PATH", "wallet json's path") { |wallet_path|
          @wallet_path = wallet_path
        }
        parser.on("-n NODE", "--node=NODE", "Connecting node") { |node|
          @node = node
        }
        parser.on("--testnet", "Set network type as testnet (default is mainnet)") {
          @is_testnet = true
        }
      end
    end

    def run_impl(action_name)
      unless wallet_path = @wallet_path
        puts_help(HELP_WALLET_PATH)
      end

      unless node = @node
        puts_help(HELP_CONNECTING_NODE)
      end

      node_uri = URI.parse(node)

      unless host = node_uri.host
        puts_help(HELP_CONNECTING_NODE)
      end

      unless port = node_uri.port
        puts_help(HELP_CONNECTING_NODE)
      end

      wallet = Core::Wallet.from_path(wallet_path)
      wallet_is_testnet = (Core::Wallet.address_network_type(wallet.address)[:name] == "testnet")

      raise "Wallet type mismatch" if @is_testnet != wallet_is_testnet

      miner = Core::Miner.new(@is_testnet, host, port, wallet)
      miner.run
    end
  end
end
