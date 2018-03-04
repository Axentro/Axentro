module ::Sushi::Interface::Sushi
  class Scars < CLI
    def sub_actions
      [
        {
          name: "buy",
          desc: "buy specified domain",
        },
        {
          name: "sell",
          desc: "sell your domain",
        },
        {
          name: "sales",
          desc: "show list for sales",
        },
        {
          name: "resolve",
          desc: "show an address of the domain if it's registered",
        },
      ]
    end

    def option_parser
      create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
        Options::JSON,
        Options::FEE,
        Options::PRICE,
        Options::DOMAIN,
      ])
    end

    def run_impl(action_name)
      case action_name
      when "buy"
        return buy
      when "sell"
        return sell
      when "sales"
        return sales
      when "resolve"
        return resolve
      end

      specify_sub_action!
    end

    def buy
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = __wallet_path
      puts_help(HELP_FEE) unless fee = __fee
      puts_help(HELP_PRICE) unless price = __price
      puts_help(HELP_DOMAIN) unless domain = __domain

      wallet = get_wallet(wallet_path, __wallet_password)

      puts "debug: buy"

      senders = Core::Models::Senders.new
      senders.push({
        address:    wallet.address,
        public_key: wallet.public_key,
        amount:     price + fee,
      })

      recipients = Core::Models::Recipients.new

      # unsigned_transaction = create_unsigned_transaction(node, "scars_buy", senders, recipients, domain)
      #
      # puts_success unsigned_transaction.to_json
      #
      # signed_transaction = sign(wallet, unsigned_transaction)
      #
      # puts_success signed_transaction.to_json
      #
      # payload = {
      #   call: "scars_buy",
      #   transaction: signed_transaction.to_json,
      # }
      #
      # rpc(node, payload)

      add_transaction(node, wallet, "scars_buy", senders, recipients, domain)
    end

    def sell
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = __wallet_path
      puts_help(HELP_FEE) unless fee = __fee
      puts_help(HELP_PRICE) unless price = __price
      puts_help(HELP_DOMAIN) unless domain = __domain

      puts "debug: sell"
    end

    def sales
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node

      payload = {call: "scars_sales"}.to_json

      body = rpc(node, payload)

      puts_success "debug: sales"
      puts_success body
    end

    def resolve
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node
      puts_help(HELP_DOMAIN) unless domain = __domain

      payload = {call: "scars_resolve", domain_name: domain}.to_json

      body = rpc(node, payload)

      puts_success "debug: resolve"
      puts_success body
    end

    include GlobalOptionParser
  end
end
