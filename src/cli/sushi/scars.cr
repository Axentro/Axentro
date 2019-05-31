# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

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
          name: "cancel",
          desc: "cancel selling",
        },
        {
          name: "resolve",
          desc: "show an address of the domain if it's registered",
        },
        {
          name: "sales",
          desc: "show a list of domains for sale",
        },
      ]
    end

    def option_parser
      G.op.create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
        Options::JSON,
        Options::CONFIRMATION,
        Options::FEE,
        Options::PRICE,
        Options::DOMAIN,
        Options::CONFIG_NAME,
      ])
    end

    def run_impl(action_name)
      case action_name
      when "buy"
        return buy
      when "cancel"
        return cancel
      when "sell"
        return sell
      when "resolve"
        return resolve
      when "sales"
        return sales
      end

      specify_sub_action!
    rescue e : Exception
      puts_error e.message
    end

    def buy
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path
      puts_help(HELP_FEE) unless fee = G.op.__fee
      puts_help(HELP_PRICE) unless price = G.op.__price
      puts_help(HELP_DOMAIN) unless domain = G.op.__domain

      Core::DApps::BuildIn::Scars.valid_domain?(domain)

      resolved = resolve_internal(node, domain, 1)

      wallet = get_wallet(wallet_path, G.op.__wallet_password)

      senders = SendersDecimal.new
      senders.push({
        address:    wallet.address,
        public_key: wallet.public_key,
        amount:     price,
        fee:        fee,
        sign_r:     "0",
        sign_s:     "0",
      })

      recipients = RecipientsDecimal.new

      if resolved["resolved"].as_bool
        resolved_price = resolved["domain"]["price"].as_s
        resolved_address = resolved["domain"]["address"].as_s

        recipients.push({
          address: resolved_address,
          amount:  resolved_price,
        })
      end

      add_transaction(node, "scars_buy", [wallet], senders, recipients, domain, TOKEN_DEFAULT)
    end

    def sell
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path
      puts_help(HELP_FEE) unless fee = G.op.__fee
      puts_help(HELP_PRICE) unless price = G.op.__price
      puts_help(HELP_DOMAIN) unless domain = G.op.__domain

      resolved = resolve_internal(node, domain, 1)

      raise "the domain #{domain} is not resolved" unless resolved["resolved"].as_bool

      if resolved["domain"]["status"] == Core::DApps::BuildIn::Scars::Status::FOR_SALE
        raise "the domain #{domain} is already for sale"
      end

      wallet = get_wallet(wallet_path, G.op.__wallet_password)

      senders = SendersDecimal.new
      senders.push({
        address:    wallet.address,
        public_key: wallet.public_key,
        amount:     price,
        fee:        fee,
        sign_r:     "0",
        sign_s:     "0",
      })

      recipients = RecipientsDecimal.new
      recipients.push({
        address: wallet.address,
        amount:  price,
      })

      add_transaction(node, "scars_sell", [wallet], senders, recipients, domain, TOKEN_DEFAULT)
    end

    def cancel
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path
      puts_help(HELP_FEE) unless fee = G.op.__fee
      puts_help(HELP_DOMAIN) unless domain = G.op.__domain

      resolved = resolve_internal(node, domain, 1)

      raise "the domain #{domain} is not resolved" unless resolved["resolved"].as_bool

      unless resolved["domain"]["status"] == Core::DApps::BuildIn::Scars::Status::FOR_SALE
        raise "the domain #{domain} is not for sale"
      end

      wallet = get_wallet(wallet_path, G.op.__wallet_password)

      senders = SendersDecimal.new
      senders.push({
        address:    wallet.address,
        public_key: wallet.public_key,
        amount:     "0",
        fee:        fee,
        sign_r:     "0",
        sign_s:     "0",
      })

      recipients = RecipientsDecimal.new
      recipients.push({
        address: wallet.address,
        amount:  "0",
      })

      add_transaction(node, "scars_cancel", [wallet], senders, recipients, domain, TOKEN_DEFAULT)
    end

    def sales
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node

      payload = {call: "scars_for_sale"}.to_json

      body = rpc(node, payload)

      if G.op.__json
        puts body
      else
        puts_success "\n SCARS domains for sale!\n"

        puts "   %20s | %64s | %s" % ["Domain", "Address", "Price"]

        json = JSON.parse(body)
        json.as_a.each do |domain|
          puts " - %20s | %64s | %s" % [domain["domain_name"].as_s, domain["address"].as_s, domain["price"].as_s]
        end

        puts
      end
    end

    def resolve
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_DOMAIN) unless domain = G.op.__domain

      resolved = resolve_internal(node, domain, G.op.__confirmation)

      if G.op.__json
        puts resolved.to_json
      else
        puts_success "show information of domain #{domain}"
        puts_success "resolved : #{resolved["resolved"]}"

        status = case resolved["domain"]["status"].as_i
                 when Core::DApps::BuildIn::Scars::Status::ACQUIRED
                   "acquired"
                 when Core::DApps::BuildIn::Scars::Status::FOR_SALE
                   "for sale"
                 when Core::DApps::BuildIn::Scars::Status::NOT_FOUND
                   "not found"
                 end

        puts_success "address  : #{resolved["domain"]["address"]}"
        puts_success "status   : #{status}"
        puts_success "price    : #{resolved["domain"]["price"].as_s}"
      end
    end
  end
end
