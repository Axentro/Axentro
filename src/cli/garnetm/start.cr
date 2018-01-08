module ::Garnet::Interface
  class Start < CLI
    @wallet_path : String?
    @node : String?

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
      end
    end

    def run_impl(action_name)
      unless wallet_path = @wallet_path
        puts_help("Please specify your wallet")
      end

      unless node = @node
        puts_help("Please specify a connecting node")
      end

      node_uri = URI.parse(node)

      unless host = node_uri.host
        puts_help("Please specify a connecting node list -node='http[s]://<host>:<port>'")
      end

      unless port = node_uri.port
        puts_help("Please specify a connecting node list -node='http[s]://<host>:<port>'")
      end

      miner = Core::Miner.new(host, port, wallet_path)
      miner.run
    end
  end
end
