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
        Options::UNCONFIRMED,
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

      raise "invalid fee for the action buy: minimum fee is #{min_fee_of_action("scars_buy")}" if fee < min_fee_of_action("scars_buy")

      wallet = get_wallet(wallet_path, __wallet_password)

      senders = Core::Models::Senders.new
      senders.push({
        address:    wallet.address,
        public_key: wallet.public_key,
        amount:     price,
        fee: fee,
      })

      recipients = Core::Models::Recipients.new

      add_transaction(node, wallet, "scars_buy", senders, recipients, domain)
    end

    def sell
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = __wallet_path
      puts_help(HELP_FEE) unless fee = __fee
      puts_help(HELP_PRICE) unless price = __price
      puts_help(HELP_DOMAIN) unless domain = __domain

      raise "invalid fee for the action sell: minimum fee is #{min_fee_of_action("scars_sell")}" if fee < min_fee_of_action("scars_sell")

      resolved = resolve_internal(node, domain, true)

      puts_help(HELP_DOMAIN_NOT_RESOLVED % domain) unless resolved["resolved"].as_bool

      wallet = get_wallet(wallet_path, __wallet_password)

      senders = Core::Models::Senders.new
      senders.push({
        address:    wallet.address,
        public_key: wallet.public_key,
        amount:     price,
        fee: fee,
      })

      recipients = Core::Models::Recipients.new
      recipients.push({
        address: resolved["domain"]["address"].as_s,
        amount:  price,
      })

      add_transaction(node, wallet, "scars_sell", senders, recipients, domain)
    end

    def sales
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node

      payload = {call: "scars_sales"}.to_json

      body = rpc(node, payload)

      puts_success body
    end

    def resolve
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node
      puts_help(HELP_DOMAIN) unless domain = __domain

      resolved = resolve_internal(node, domain, __unconfirmed)

      unless __json
        puts_success "show information of domain #{domain}"
        puts_success "resolved : #{resolved["resolved"]}"

        if resolved["resolved"].as_bool
          status = case resolved["domain"]["status"].as_i
                   when 0
                     "acquired"
                   when 1
                     "for sale"
                   end

          puts_success "address  : #{resolved["domain"]["address"]}"
          puts_success "status   : #{status}"
          puts_success "price    : #{resolved["domain"]["price"]}"
        end
      else
        puts_info resolved.to_json
      end
    end

    def resolve_internal(node, domain, unconfirmed : Bool) : JSON::Any
      payload = {call: "scars_resolve", domain_name: domain, unconfirmed: unconfirmed}.to_json

      body = rpc(node, payload)

      JSON.parse(body)
    end

    include Core::Fees
    include GlobalOptionParser
  end
end
