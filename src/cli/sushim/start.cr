module ::Sushi::Interface
  class Start < CLI
    @wallet_path : String?
    @node : String?

    def sub_actions
      [] of SushiAction
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

      miner = Core::Miner.new(host, port, wallet_path)
      miner.run
    end
  end
end
