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
  class Token < CLI
    def sub_actions
      [
        {
          name: "create",
          desc: "create your token",
        },
        {
          name: "list",
          desc: "list existing tokens",
        },
      ]
    end

    def option_parser
      G.op.create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
        Options::JSON,
        Options::AMOUNT,
        Options::FEE,
        Options::PRICE,
        Options::TOKEN,
        Options::CONFIG_NAME,
      ])
    end

    def run_impl(action_name)
      case action_name
      when "create"
        return create
      when "list"
        return list
      end

      specify_sub_action!
    rescue e : Exception
      puts_error e.message
    end

    def create
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path
      puts_help(HELP_FEE) unless fee = G.op.__fee
      puts_help(HELP_AMOUNT) unless amount = G.op.__amount
      puts_help(HELP_TOKEN) unless token = G.op.__token

      raise "please specify your original token name" if token == TOKEN_DEFAULT

      wallet = get_wallet(wallet_path, G.op.__wallet_password)

      senders = SendersDecimal.new
      senders.push({
        address:    wallet.address,
        public_key: wallet.public_key,
        amount:     amount,
        fee:        fee,
        sign_r:     "0",
        sign_s:     "0",
      })

      recipients = RecipientsDecimal.new
      recipients.push({
        address: wallet.address,
        amount:  amount,
      })

      add_transaction(node, "create_token", [wallet], senders, recipients, "", token)
    end

    def list
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node

      payload = {call: "token_list"}.to_json

      body = rpc(node, payload)
      json = JSON.parse(body)

      if G.op.__json
        puts body
      else
        puts_success "show a list of every token in SushiChain"

        json.as_a.each do |token|
          puts_info "- #{token}"
        end
      end
    end
  end
end
