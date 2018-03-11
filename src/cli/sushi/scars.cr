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

      raise "invalid fee for the action buy: minimum fee is #{Core::Scars.fee("scars_buy")}" if fee < Core::Scars.fee("scars_buy")

      resolved = resolve_internal(node, domain, false)

      wallet = get_wallet(wallet_path, __wallet_password)

      senders = Core::Models::Senders.new
      senders.push({
        address:    wallet.address,
        public_key: wallet.public_key,
        amount:     price,
        fee:        fee,
      })

      recipients = Core::Models::Recipients.new

      if resolved["resolved"].as_bool
        resolved_price = resolved["domain"]["price"].as_i64
        resolved_address = resolved["domain"]["address"].as_s

        raise "invalid price. you specified #{price} but the price is #{resolved_price}" if resolved_price != price

        recipients.push({
          address: resolved_address,
          amount:  resolved_price,
        })
      end

      add_transaction(node, wallet, "scars_buy", senders, recipients, domain)
    end

    def sell
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = __wallet_path
      puts_help(HELP_FEE) unless fee = __fee
      puts_help(HELP_PRICE) unless price = __price
      puts_help(HELP_DOMAIN) unless domain = __domain

      raise "invalid fee for the action sell: minimum fee is #{Core::Scars.fee("scars_sell")}" if fee < Core::Scars.fee("scars_sell")

      resolved = resolve_internal(node, domain, false)

      puts_help(HELP_DOMAIN_NOT_RESOLVED % domain) unless resolved["resolved"].as_bool

      wallet = get_wallet(wallet_path, __wallet_password)

      senders = Core::Models::Senders.new
      senders.push({
        address:    wallet.address,
        public_key: wallet.public_key,
        amount:     price,
        fee:        fee,
      })

      recipients = Core::Models::Recipients.new
      recipients.push({
        address: wallet.address,
        amount:  price,
      })

      add_transaction(node, wallet, "scars_sell", senders, recipients, domain)
    end

    def resolve
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node
      puts_help(HELP_DOMAIN) unless domain = __domain

      resolved = resolve_internal(node, domain, !__unconfirmed)

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

    include GlobalOptionParser
  end
end
