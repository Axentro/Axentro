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
  class Wallet < CLI
    def sub_actions
      [
        {
          name: I18n.translate("sushi.cli.wallet.create.title"),
          desc: I18n.translate("sushi.cli.wallet.create.desc"),
        },
        {
          name: "verify",
          desc: "verify a wallet file",
        },
        {
          name: "encrypt",
          desc: "encrypt a sushi wallet",
        },
        {
          name: "decrypt",
          desc: "decrypt a sushi wallet (that was encrypted using sushi)",
        },
        {
          name: "amount",
          desc: "show remaining amount of Sushi tokens for specified address",
        },
      ]
    end

    def option_parser
      G.op.create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
        Options::IS_TESTNET,
        Options::ENCRYPTED,
        Options::JSON,
        Options::CONFIRMATION,
        Options::ADDRESS,
        Options::DOMAIN,
        Options::TOKEN,
        Options::CONFIG_NAME
      ])
    end

    def run_impl(action_name)
      case action_name
      when I18n.translate("sushi.cli.wallet.create.title")
        return create
      when "verify"
        return verify
      when "encrypt"
        return encrypt
      when "decrypt"
        return decrypt
      when "amount"
        return amount
      end

      specify_sub_action!(action_name)
    rescue e : Exception
      puts_error e.message
    end

    def create
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path

      wallet_path = wallet_path.ends_with?(".json") ? wallet_path : wallet_path + ".json"

      puts_help(HELP_WALLET_ALREADY_EXISTS % wallet_path) if File.exists?(wallet_path)

      wallet = Core::Wallet.from_json(Core::Wallet.create(G.op.__is_testnet).to_json)

      if G.op.__encrypted
        puts_help(HELP_WALLET_PASSWORD) unless wallet_password = (G.op.__wallet_password || ENV["SC_WALLET_PASSWORD"]?)

        encrypted_wallet = Core::Wallet.encrypt(wallet_password, wallet)

        File.write(wallet_path, encrypted_wallet.to_json)
      else
        File.write(wallet_path, wallet.to_json)
      end

      if G.op.__json
        puts wallet.to_json
      else
        puts_success("your new wallet has been created at #{wallet_path}")
        puts_success("please make a backup of the json file and keep it secret.")
      end
    end

    def verify
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path

      wallet = get_wallet(wallet_path, G.op.__wallet_password)

      puts_success "#{wallet_path} is perfect!" if wallet.verify!
      puts_success "address: #{wallet.address}"

      network = Core::Wallet.address_network_type(wallet.address)
      puts_success "network (#{network[:prefix]}): #{network[:name]}"
    end

    def encrypt
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path
      puts_help(HELP_WALLET_PASSWORD) unless wallet_password = G.op.__wallet_password

      encrypted_wallet_json = Core::Wallet.encrypt(wallet_password, wallet_path).to_json
      encrypted_wallet_path = File.dirname(wallet_path) + "/encrypted-" + File.basename(wallet_path)

      puts_help(HELP_WALLET_ALREADY_EXISTS % encrypted_wallet_path) if File.exists?(encrypted_wallet_path)

      File.write(encrypted_wallet_path, encrypted_wallet_json)

      if G.op.__json
        puts encrypted_wallet_json
      else
        puts_success("your wallet has been encrypted at #{encrypted_wallet_path}")
        puts_success("please don't forget your password - there is no way to recover an encrypted wallet.")
      end
    end

    def decrypt
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path
      puts_help(HELP_WALLET_PASSWORD) unless wallet_password = G.op.__wallet_password

      decrypted_wallet_json = Core::Wallet.decrypt(wallet_password, wallet_path)
      decrypted_wallet_path = File.dirname(wallet_path) + "/decrypted-" + File.basename(wallet_path)

      puts_help(HELP_WALLET_ALREADY_EXISTS % decrypted_wallet_path) if File.exists?(decrypted_wallet_path)

      File.write(decrypted_wallet_path, decrypted_wallet_json)

      if G.op.__json
        puts decrypted_wallet_json
      else
        puts_success("your wallet has been decrypted at #{decrypted_wallet_path}")
      end
    end

    private def determine_address(node) : String
      if wallet_path = G.op.__wallet_path
        wallet = get_wallet(wallet_path, G.op.__wallet_password)
        wallet.address
      elsif _address = G.op.__address
        _address
      elsif _domain = G.op.__domain
        resolved = resolve_internal(node, _domain, G.op.__confirmation)
        raise "domain #{_domain} is not resolved" unless resolved["resolved"].as_bool
        resolved["domain"]["address"].as_s
      else
        puts_help(HELP_WALLET_PATH_OR_ADDRESS_OR_DOMAIN)
      end
    end

    def amount
      puts_help(HELP_WALLET_PATH_OR_ADDRESS_OR_DOMAIN) if G.op.__wallet_path.nil? && G.op.__address.nil? && G.op.__domain.nil?
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node

      token = if _token = G.op.__token
                _token
              else
                "all"
              end

      address = determine_address(node)

      payload = {call: "amount", address: address, confirmation: G.op.__confirmation, token: token}.to_json

      body = rpc(node, payload)
      json = JSON.parse(body)

      if G.op.__json
        puts body
      else
        puts_success("\n  showing amount of each token for #{address}.")
        puts_success("  confirmation: #{G.op.__confirmation}\n")

        puts_info("  + %20s - %20s +" % ["-" * 20, "-" * 20])
        puts_info("  | %20s | %20s |" % ["token", "amount"])
        puts_info("  | %20s | %20s |" % ["-" * 20, "-" * 20])

        json["pairs"].as_a.each do |pair|
          amount = BigDecimal.new(pair["amount"].as_s)

          next if pair["token"] != TOKEN_DEFAULT && amount == 0
          puts_info("  | %20s | %20s |" % [pair["token"], amount])
        end

        puts_info("  + %20s - %20s +" % ["-" * 20, "-" * 20])
        puts_info("")
      end
    end
  end
end
