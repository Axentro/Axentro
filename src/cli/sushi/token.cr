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
      create_option_parser([
                             Options::CONNECT_NODE,
                             Options::WALLET_PATH,
                             Options::WALLET_PASSWORD,
                             Options::JSON,
                             Options::AMOUNT,
                             Options::FEE,
                             Options::PRICE,
                             Options::TOKEN,
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
    end

    def create
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = __wallet_path
      puts_help(HELP_FEE) unless fee = __fee
      puts_help(HELP_AMOUNT) unless amount = __amount
      puts_help(HELP_TOKEN) unless token = __token

      raise "please specify your original token name" if token == TOKEN_DEFAULT

      wallet = get_wallet(wallet_path, __wallet_password)

      senders = Core::Models::Senders.new
      senders.push({
                     address: wallet.address,
                     public_key: wallet.public_key,
                     amount: amount,
                     fee: fee,
                   })

      recipients = Core::Models::Recipients.new
      recipients.push({
                        address: wallet.address,
                        amount: amount,
                      })

      add_transaction(node, wallet, "create_token", senders, recipients, "", token)
    end

    def list
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node

      payload = {call: "token_list"}.to_json

      body = rpc(node, payload)

      puts_success body
    end

    include GlobalOptionParser
  end
end
