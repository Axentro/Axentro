module ::Sushi::Interface
  class Start < CLI
    @bind_host     : String = "0.0.0.0"
    @bind_port     : Int32  = 3000
    @public_url    : String?
    @connect_node  : String?
    @wallet_path   : String?
    @database_path : String?
    @is_testnet    : Bool = false

    def sub_actions
      [] of SushiAction
    end

    def option_parser
      OptionParser.new do |parser|
        parser.on("-h BIND_HOST", "--bind_host=BIND_HOST", "Bind host; '0.0.0.0' by default") { |bind_host|
          raise "Invalid host: #{bind_host}" unless bind_host.count('.') == 3
          @bind_host = bind_host
        }
        parser.on("-p BIND_PORT", "--bind_port=BIND_PORT", "Bind port; 3000 by default") { |bind_port|
          @bind_port = bind_port.to_i
        }
        parser.on("-u PUBLIC_URL", "--public_url=PUBLIC_URL", "Public url that can be accessed from internet") { |public_url|
          @public_url = public_url
        }
        parser.on("-n NODE", "--node=NODE", "Connecting node") { |connect_node|
          @connect_node = connect_node
        }
        parser.on("-d DATABASE", "--database=DATABASE", "Path to a database (SQLite3)") { |database_path|
          @database_path = database_path
        }
        parser.on(
          "-w WALLET_PATH",
          "--wallet-path=WALLET_PATH",
          "wallet json's path",
        ) { |wallet_path| @wallet_path = wallet_path }
        parser.on("--testnet", "Set network type as testnet (default is mainnet)") {
          @is_testnet = true
        }
      end
    end

    def run_impl(action_name)
      unless wallet_path = @wallet_path
        puts_help(HELP_WALLET_PATH)
      end

      unless public_url = @public_url
        puts_help(HELP_PUBLIC_URL)
      end

      public_uri = URI.parse(public_url)

      unless public_host = public_uri.host
        puts_help(HELP_PUBLIC_URL)
      end

      unless public_port = public_uri.port
        puts_help(HELP_PUBLIC_URL)
      end

      has_first_connection = false

      if connect_node = @connect_node
        connect_uri = URI.parse(connect_node)
        has_first_connection = !connect_uri.host.nil? && !connect_uri.port.nil?
      end

      wallet = Core::Wallet.from_path(wallet_path)

      database = if database_path = @database_path
                   Core::Database.new(database_path)
                 else
                   nil
                 end

      node = has_first_connection ?
               Core::Node.new(@is_testnet, @bind_host, @bind_port,
                              public_host, public_port,
                              connect_uri.not_nil!.host, connect_uri.not_nil!.port, wallet, database) :
               Core::Node.new(@is_testnet, @bind_host, @bind_port,
                              public_host, public_port,
                              nil, nil, wallet, database)
      node.run!
    end

    include Logger
    include Core::Protocol
  end
end
