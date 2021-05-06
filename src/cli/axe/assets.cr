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
  class AssetCli < CLI
    def sub_actions : Array(AxeAction)
      [
        {
          name: I18n.translate("axe.cli.assets.create.title"),
          desc: I18n.translate("axe.cli.assets.create.desc"),
        },
        {
          name: I18n.translate("axe.cli.assets.update.title"),
          desc: I18n.translate("axe.cli.assets.update.desc"),
        },
        {
          name: I18n.translate("axe.cli.assets.send.title"),
          desc: I18n.translate("axe.cli.assets.send.desc"),
        },
        {
          name: I18n.translate("axe.cli.assets.get.title"),
          desc: I18n.translate("axe.cli.assets.get.desc"),
        },
        {
          name: I18n.translate("axe.cli.assets.amount.title"),
          desc: I18n.translate("axe.cli.assets.amount.desc"),
        },
      ]
    end

    def option_parser : OptionParser?
      G.op.create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
        Options::ASSET_ID,
        Options::ASSET_NAME,
        Options::ASSET_DESCRIPTION,
        Options::ASSET_MEDIA_LOCATION,
        Options::ASSET_LOCKED,
        Options::JSON,
        Options::ADDRESS,
        Options::AMOUNT,
        Options::DOMAIN,
        Options::CONFIG_NAME,
        Options::IS_FAST_TRANSACTION,
      ])
    end

    def run_impl(action_name) : OptionParser?
      case action_name
      when I18n.translate("axe.cli.assets.create.title")
        return create
      when I18n.translate("axe.cli.assets.update.title")
        return update
      when I18n.translate("axe.cli.assets.send.title")
        return send
      when I18n.translate("axe.cli.assets.get.title")
        return get
      when I18n.translate("axe.cli.assets.amount.title")
        return amount
      end

      specify_sub_action!(action_name)
    rescue e : Exception
      puts_error e.message
    end

    def create
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path
      puts_help(HELP_ASSET_NAME) unless asset_name = G.op.__asset_name
      puts_help(HELP_ASSET_DESCRIPTION) unless asset_description = G.op.__asset_description
      puts_help(HELP_ASSET_MEDIA_LOCATION) unless asset_media_location = G.op.__asset_media_location
      puts_help(HELP_ASSET_AMOUNT) unless amount = G.op.__amount

      action = "create_asset"

      wallet = get_wallet(wallet_path, G.op.__wallet_password)
      wallets = [wallet]

      senders = SendersDecimal.new
      senders.push(
        SenderDecimal.new(wallet.address, wallet.public_key, "0", "0", "0")
      )

      recipients = RecipientsDecimal.new
      recipients.push(
        RecipientDecimal.new(wallet.address, "0")
      )

      kind = G.op.__is_fast_transaction ? TransactionKind::FAST : TransactionKind::SLOW

      locked = G.op.__asset_locked ? AssetAccess::LOCKED : AssetAccess::UNLOCKED

      asset_id = Transaction::Asset.create_id
      asset = Transaction::Asset.new(
        asset_id, asset_name, asset_description, asset_media_location, "", amount.to_i, "", locked, 1, __timestamp)

      modules = [] of Transaction::Module
      inputs = [] of Transaction::Input
      outputs = [] of Transaction::Output

      add_transaction(node, action, wallets, senders, recipients, [asset], modules, inputs, outputs, "", G.op.__message, TOKEN_DEFAULT, kind)
    end

    def update
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path
      puts_help(HELP_ASSET_ID) unless asset_id = G.op.__asset_id

      action = "update_asset"

      wallet = get_wallet(wallet_path, G.op.__wallet_password)
      wallets = [wallet]

      senders = SendersDecimal.new
      senders.push(
        SenderDecimal.new(wallet.address, wallet.public_key, "0", "0", "0")
      )

      recipients = RecipientsDecimal.new
      recipients.push(
        RecipientDecimal.new(wallet.address, "0")
      )

      kind = G.op.__is_fast_transaction ? TransactionKind::FAST : TransactionKind::SLOW

      # for convenience fetch the asset and then only update fields provided by user
      payload = {call: "asset", asset_id: asset_id}.to_json

      body = rpc(node, payload)
      json = JSON.parse(body)

      if json["status"] == "not found"
        puts_error "no asset found with id: #{asset_id}"
      else
        asset = Transaction::Asset.from_json(json["asset"].as_h.to_json)

        asset.name = G.op.__asset_name || asset.name
        asset.description = G.op.__asset_description || asset.description
        asset.media_location = G.op.__asset_media_location || asset.media_location
        asset.quantity = G.op.__amount.try(&.to_i) || asset.quantity
        asset.version = asset.version + 1
        asset.timestamp = __timestamp

        if asset.locked == AssetAccess::UNLOCKED
          asset.locked = G.op.__asset_locked ? AssetAccess::LOCKED : asset.locked
        end

        modules = [] of Transaction::Module
        inputs = [] of Transaction::Input
        outputs = [] of Transaction::Output

        add_transaction(node, action, wallets, senders, recipients, [asset], modules, inputs, outputs, "", G.op.__message, TOKEN_DEFAULT, kind)
      end
    end

    def send
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path
      puts_help(HELP_ASSET_ID) unless asset_id = G.op.__asset_id
      puts_help(HELP_ASSET_AMOUNT) unless amount = G.op.__amount
      puts_help(HELP_ADDRESS_DOMAIN_RECIPIENT) if G.op.__address.nil? && G.op.__domain.nil?

      action = "send_asset"

      recipient_address = if address = G.op.__address
                            address
                          else
                            resolved = resolve_internal(node, G.op.__domain.not_nil!)
                            raise "domain #{G.op.__domain.not_nil!} is not resolved" unless resolved["resolved"].as_bool
                            resolved["domain"]["address"].as_s
                          end

      to_address = Address.from(recipient_address, "recipient")

      wallet = get_wallet(wallet_path, G.op.__wallet_password)
      wallets = [wallet]

      senders = SendersDecimal.new
      senders.push(
        SenderDecimal.new(wallet.address, wallet.public_key, "0", "0", "0", asset_id, amount.to_i)
      )

      recipients = RecipientsDecimal.new
      recipients.push(
        RecipientDecimal.new(to_address.as_hex, "0", asset_id, amount.to_i)
      )

      kind = G.op.__is_fast_transaction ? TransactionKind::FAST : TransactionKind::SLOW

      add_transaction(node, action, wallets, senders, recipients, [] of Transaction::Asset, [] of Transaction::Module, [] of Transaction::Input, [] of Transaction::Output, "", G.op.__message, TOKEN_DEFAULT, kind)
    end

    def get
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_ASSET_ID) unless asset_id = G.op.__asset_id

      payload = {call: "asset", asset_id: asset_id}.to_json

      body = rpc(node, payload)
      json = JSON.parse(body)

      if G.op.__json
        puts body
      else
        if json["status"] == "not found"
          puts_error "no asset found with id: #{asset_id}"
        else
          confirmations = json["confirmations"]
          puts_success(I18n.translate("axe.cli.assets.amount.messages.confirmation", {confirmation: confirmations}))

          a = json["asset"].as_h

          table = Tallboy.table do
            columns do
              add "asset id"
              add "name"
              add "quantity", align: :center
              add "version", align: :center
              add "status"
              add "media_location"
            end
            header
            rows [[a["asset_id"], a["name"], a["quantity"], a["version"], a["locked"], a["media_location"]]]
          end

          puts table.render
        end
      end
    end

    def amount
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_WALLET_PATH_OR_ADDRESS_OR_DOMAIN) if G.op.__wallet_path.nil? && G.op.__address.nil? && G.op.__domain.nil?

      address = determine_address(node, G.op.__wallet_path, G.op.__wallet_password, G.op.__address, G.op.__domain)

      payload = {call: "asset_balance", address: address}.to_json

      body = rpc(node, payload)
      json = JSON.parse(body)

      if G.op.__json
        puts body
      else
        assets = json["assets"].as_a
        if assets.empty?
          puts_success(I18n.translate("axe.cli.assets.amount.messages.amount", {address: address}))
          puts_success(I18n.translate("axe.cli.assets.amount.messages.no_assets"))
        else
          confirmations = json["confirmations"]

          puts_success(I18n.translate("axe.cli.assets.amount.messages.amount", {address: address}))
          puts_success(I18n.translate("axe.cli.assets.amount.messages.confirmation", {confirmation: confirmations}))

          table = Tallboy.table do
            columns do
              add "asset id"
              add "quanity"
            end
            header
            rows [assets.flat_map { |a| [a["asset_id"], a["quantity"]] }]
          end

          puts table.render
        end
      end
    end
  end
end
