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
  class Auth < CLI
    def sub_actions
      [
        {
          name: "enable",
          desc: "enable 2fa",
        },
        {
          name: "disable",
          desc: "disable 2fa",
        },
        {
          name: "verify",
          desc: "verify 2fa",
        },
      ]
    end

    def option_parser
      create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
        Options::JSON,
        Options::CONFIRMATION,
        Options::FEE,
        Options::AUTH_CODE,
        Options::CONFIG_NAME,
      ])
    end

    def run_impl(action_name)
      case action_name
      when "enable"
        return enable
      when "disable"
        return disable
      when "verify"
        return verify
      end

      specify_sub_action!
    rescue e : Exception
      puts_error e.message
      exit -1
    end

    def enable
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = __wallet_path
      puts_help(HELP_FEE) unless fee = __fee

      wallet = get_wallet(wallet_path, __wallet_password)
      resolved_secret_code = resolve_2fa_secret(node, wallet.address, 1)
      raise "2fa is already enabled on this address" if resolved_secret_code["secret_code"]["status"] == Core::DApps::BuildIn::Auth::Status::Enabled

      wallet = get_wallet(wallet_path, __wallet_password)

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

      generated_secret_code = TOTP.generate_base32_secret
      add_transaction(node, "2fa_enable", [wallet], senders, recipients, "", TOKEN_DEFAULT, generated_secret_code)
    end

    def disable
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = __wallet_path
      puts_help(HELP_FEE) unless fee = __fee
      puts_help(HELP_AUTH_CODE) unless auth_code = __auth_code

      wallet = get_wallet(wallet_path, __wallet_password)

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

      add_transaction(node, "2fa_disable", [wallet], senders, recipients, "", TOKEN_DEFAULT, auth_code)
    end

    def verify
        puts_help(HELP_CONNECTING_NODE) unless node = __connect_node
        puts_help(HELP_WALLET_PATH) unless wallet_path = __wallet_path
        puts_help(HELP_AUTH_CODE) unless auth_code = __auth_code

        wallet = get_wallet(wallet_path, __wallet_password)
        secret_code_response = resolve_2fa_secret(node, wallet.address, 1)
        secret_code = secret_code_response["secret_code"]["secret_code"].to_s
        raise "2fa is not enabled on this address" if secret_code.empty?
        puts "verifying 2fa ..."
        result = TOTP.validate_number_string(secret_code, auth_code)
        if result
          puts_success("The 2fa code you supplied was successfully validated!")
        else
          puts_error("The 2fa code you supplied was incorrect!")
        end


    end

    include GlobalOptionParser
  end

end
