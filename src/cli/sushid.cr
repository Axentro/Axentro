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
                             Options::CONN_MIN,
                           ])
    end

    def run_impl(action_name)
      puts_help(HELP_WALLET_PATH) unless wallet_path = @wallet_path

      unless @is_private
        puts_help(HELP_PUBLIC_URL) unless public_url = @public_url

        public_uri = URI.parse(public_url)

        puts_help(HELP_PUBLIC_URL) unless public_host = public_uri.host
        puts_help(HELP_PUBLIC_URL) unless public_port = public_uri.port

        ssl = (public_uri.scheme == "https")
      end

      has_first_connection = false

      if connect_node = @connect_node
        connect_uri = URI.parse(connect_node)
        has_first_connection = !connect_uri.host.nil? && !connect_uri.port.nil?
      end

      wallet = get_wallet(wallet_path, @wallet_password)

      database = if database_path = @database_path
                   Core::Database.new(database_path)
                 else
                   nil
                 end

      node = has_first_connection ?
               Core::Node.new(@is_private, @is_testnet, @bind_host, @bind_port,
                              public_host, public_port, ssl,
                              connect_uri.not_nil!.host, connect_uri.not_nil!.port, wallet, database, @conn_min) :
               Core::Node.new(@is_private, @is_testnet, @bind_host, @bind_port,
                              public_host, public_port, ssl,
                              nil, nil, wallet, database, @conn_min)
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
  {name: "sushid", desc: "Sushi's node"}, [] of SushiAction, true
).run
