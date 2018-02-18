module ::Sushi::Interface::Sushi
  class Config < CLI
    def sub_actions
      [
        {
          name: "save",
          desc: "save the specified options as default for sushi, sushid and sushim",
        },
        {
          name: "show",
          desc: "show current default configuration",
        },
        {
          name: "clean",
          desc: "clean the default configuration"
        },
      ]
    end

    def option_parser
      create_option_parser([
                             Options::CONNECT_NODE,
                             Options::WALLET_PATH,
                             # Options::WALLET_PASSWORD,
                             Options::IS_TESTNET,
                             Options::IS_PRIVATE,
                             Options::JSON,
                             Options::UNCONFIRMED,
                             Options::BIND_HOST,
                             Options::BIND_PORT,
                             Options::PUBLIC_URL,
                             Options::DATABASE_PATH,
                             Options::CONN_MIN,
                             # Options::ADDRESS,
                             # Options::AMOUNT,
                             # Options::MESSAGE,
                             # Options::BLOCK_INDEX,
                             # Options::TRANSACTION_ID,
                             Options::HEADER,
                             Options::THREADS,
                             Options::ENCRYPTED,
                           ])
    end

    def run_impl(action_name)
      case action_name
      when "save"
        return save
      when "show"
        return show
      when "clean"
        return clean
      end

      specify_subaction!
    end

    def save
      cm.set("connect_node", @connect_node) if @connect_node
      cm.set("wallet_path", @wallet_path) if @wallet_path
      cm.set("is_testnet", @is_testnet)
      cm.set("is_private", @is_private)
      cm.set("json", @json)
      cm.set("unconfirmed", @unconfirmed)
      cm.set("bind_host", @bind_host)
      cm.set("bind_port", @bind_port)
      cm.set("public_url", @public_url) if @public_url
      cm.set("database_path", @database_path) if @database_path
      cm.set("conn_min", @conn_min)
      cm.set("header", @header)
      cm.set("threads", @threads)
      cm.set("encrypted", @encrypted)
      cm.save

      puts_success "saved the configuration at #{cm.config_path}"

      if config = cm.get_config
        puts_info config.to_s
      end
    end

    def show
      if config = cm.get_config
        puts_success "show current configuration at #{cm.config_path}"
        puts_info config.to_s
      else
        puts_error "no configuration found at #{cm.config_path}"
        puts_error "to create a configuration, exec `sushi config save [your_options]`"
      end
    end

    def clean
      puts_success "delete configuration at #{cm.config_path}"
      cm.clean
    end

    include GlobalOptionParser
  end
end
