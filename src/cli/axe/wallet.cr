# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

module ::Axentro::Interface::Axe
  class Wallet < CLI
    def sub_actions
      [
        {
          name: I18n.translate("axe.cli.wallet.create.title"),
          desc: I18n.translate("axe.cli.wallet.create.desc"),
        },
        {
          name: I18n.translate("axe.cli.wallet.verify.title"),
          desc: I18n.translate("axe.cli.wallet.verify.desc"),
        },
        {
          name: I18n.translate("axe.cli.wallet.encrypt.title"),
          desc: I18n.translate("axe.cli.wallet.encrypt.desc"),
        },
        {
          name: I18n.translate("axe.cli.wallet.decrypt.title"),
          desc: I18n.translate("axe.cli.wallet.decrypt.desc"),
        },
        {
          name: I18n.translate("axe.cli.wallet.amount.title"),
          desc: I18n.translate("axe.cli.wallet.amount.desc"),
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
        Options::SEED,
        Options::DERIVATION,
        Options::JSON,
        Options::ADDRESS,
        Options::DOMAIN,
        Options::TOKEN,
        Options::CONFIG_NAME,
      ])
    end

    def run_impl(action_name)
      case action_name
      when I18n.translate("axe.cli.wallet.create.title")
        return create
      when I18n.translate("axe.cli.wallet.verify.title")
        return verify
      when I18n.translate("axe.cli.wallet.encrypt.title")
        return encrypt
      when I18n.translate("axe.cli.wallet.decrypt.title")
        return decrypt
      when I18n.translate("axe.cli.wallet.amount.title")
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
      seed = nil

      if G.op.__seed || G.op.__derivation
        hd = Core::Wallet.create_hd(G.op.__seed, G.op.__derivation, G.op.__is_testnet)
        seed = hd[:seed]
        wallet = Core::Wallet.from_json(hd[:wallet].to_json)
      end

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
        puts_success(I18n.translate("axe.cli.wallet.create.messages.creation", {wallet_path: wallet_path}))
        puts_success(I18n.translate("axe.cli.wallet.create.messages.backup"))
      end
      if seed
        puts_success(I18n.translate("axe.cli.wallet.create.messages.seed", {seed: seed.not_nil!}))
      end
    end

    def verify
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path

      wallet = get_wallet(wallet_path, G.op.__wallet_password)

      puts_success I18n.translate("axe.cli.wallet.verify.messages.verify", {wallet_path: wallet_path}) if wallet.verify!
      puts_success I18n.translate("axe.cli.wallet.verify.messages.address", {wallet_address: wallet.address})

      network = Core::Wallet.address_network_type(wallet.address)
      puts_success I18n.translate("axe.cli.wallet.verify.messages.network", {network_prefix: network[:prefix], network_name: network[:name]})
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
        puts_success(I18n.translate("axe.cli.wallet.encrypt.messages.encrypt", {encrypted_wallet_path: encrypted_wallet_path}))
        puts_success(I18n.translate("axe.cli.wallet.encrypt.messages.password"))
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
        puts_success(I18n.translate("axe.cli.wallet.decrypt.messages.decrypt", {decrypted_wallet_path: decrypted_wallet_path}))
      end
    end

    private def determine_address(node) : String
      if wallet_path = G.op.__wallet_path
        wallet = get_wallet(wallet_path, G.op.__wallet_password)
        wallet.address
      elsif _address = G.op.__address
        _address
      elsif _domain = G.op.__domain
        resolved = resolve_internal(node, _domain)
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

      payload = {call: "amount", address: address, token: token}.to_json

      body = rpc(node, payload)
      json = JSON.parse(body)

      if G.op.__json
        puts body
      else
        confirmation = json["confirmation"]
        puts_success(I18n.translate("axe.cli.wallet.amount.messages.amount", {address: address}))
        puts_success(I18n.translate("axe.cli.wallet.amount.messages.confirmation", {confirmation: confirmation}))

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
