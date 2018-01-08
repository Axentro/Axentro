module ::Garnet::Interface
  class Start < CLI
    @node : String?
    @connect_node : String?
    @wallet_path  : String?

    def sub_actions
      [] of GarnetAction
    end

    def option_parser
      OptionParser.new do |parser|
        parser.on("-n NODE", "--node=NODE", "Running node") { |node|
          @node = node
        }
        parser.on("-c CONNECT_NODE", "--connect-node=CONNECT_NODE", "Connecting node") { |connect_node|
          @connect_node = connect_node
        }
        parser.on(
          "-w WALLET_PATH",
          "--wallet-path=WALLET_PATH",
          "wallet json's path",
        ) { |wallet_path| @wallet_path = wallet_path }
      end
    end

    def run_impl(action_name)
      unless wallet_path = @wallet_path
        puts_help("Please specify a wallet.json")
      end

      unless node = @node
        puts_help("Please specify a running node")
      end

      node_uri = URI.parse(node)

      unless host = node_uri.host
        puts_help("Please specify a running node like -node='http[s]://<host>:<port>'")
      end

      unless port = node_uri.port
        puts_help("Please specify a running node like -node='http[s]://<host>:<port>'")
      end

      has_first_connection = false

      if connect_node = @connect_node
        connect_uri = URI.parse(connect_node)
        has_first_connection = !connect_uri.host.nil? && !connect_uri.port.nil?
      end

      wallet = Core::Wallet.from_path(wallet_path)

      node = has_first_connection ?
               Core::Node.new(host, port, connect_uri.not_nil!.host, connect_uri.not_nil!.port, wallet) :
               Core::Node.new(host, port, nil, nil, wallet)
      node.run!
    end

    include Logger
    include Core::Protocol
  end
end
