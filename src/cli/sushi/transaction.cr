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
  class Transaction < CLI
    def sub_actions
      [
        {
          name: I18n.translate("sushi.cli.transaction.create.title"),
          desc: I18n.translate("sushi.cli.transaction.create.desc"),
        },
        {
          name: I18n.translate("sushi.cli.transaction.transactions.title"),
          desc: I18n.translate("sushi.cli.transaction.transactions.desc"),
        },
        {
          name: I18n.translate("sushi.cli.transaction.transaction.title"),
          desc: I18n.translate("sushi.cli.transaction.transaction.desc"),
        },
        {
          name: I18n.translate("sushi.cli.transaction.fees.title"),
          desc: I18n.translate("sushi.cli.transaction.fees.desc"),
        },
      ]
    end

    def option_parser
      G.op.create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
        Options::JSON,
        Options::ADDRESS,
        Options::AMOUNT,
        Options::ACTION,
        Options::MESSAGE,
        Options::BLOCK_INDEX,
        Options::TRANSACTION_ID,
        Options::FEE,
        Options::DOMAIN,
        Options::TOKEN,
        Options::CONFIG_NAME,
        Options::IS_FAST_TRANSACTION
      ])
    end

    def run_impl(action_name)
      case action_name
      when I18n.translate("sushi.cli.transaction.create.title")
        return create
      when I18n.translate("sushi.cli.transaction.transactions.title"), "txs"
        return transactions
      when I18n.translate("sushi.cli.transaction.transaction.title"), "tx"
        return transaction
      when I18n.translate("sushi.cli.transaction.fees.title")
        return fees
      end

      specify_sub_action!(action_name)
    rescue e : Exception
      puts_error e.message
    end

    def create
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path
      puts_help(HELP_AMOUNT) unless amount = G.op.__amount
      puts_help(HELP_FEE) unless fee = G.op.__fee
      puts_help(HELP_ADDRESS_DOMAIN_RECIPIENT) if G.op.__address.nil? && G.op.__domain.nil?

      action = G.op.__action || "send"

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
        {
          address:    wallet.address,
          public_key: wallet.public_key,
          amount:     amount,
          fee:        fee,
          sign_r:     "0",
          sign_s:     "0",
        }
      )

      recipients = RecipientsDecimal.new
      recipients.push(
        {
          address: to_address.as_hex,
          amount:  amount,
        }
      )

      kind = G.op.__is_fast_transaction ? TransactionKind::FAST : TransactionKind::SLOW

      add_transaction(node, action, wallets, senders, recipients, G.op.__message, G.op.__token || TOKEN_DEFAULT, kind)
    end

    def transactions
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_BLOCK_INDEX_OR_ADDRESS) if G.op.__block_index.nil? && G.op.__address.nil?

      payload = if block_index = G.op.__block_index
                  success_message = I18n.translate("sushi.cli.transaction.transactions.messages.index", {block_index: block_index})
                  {call: "transactions", index: block_index}.to_json
                elsif address = G.op.__address
                  success_message = I18n.translate("sushi.cli.transaction.transactions.messages.index", {address: address})
                  {call: "transactions", address: address}.to_json
                else
                  puts_help(HELP_BLOCK_INDEX_OR_ADDRESS)
                end

      body = rpc(node, payload)

      puts_success(success_message) unless G.op.__json
      puts body
    end

    def transaction
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_TRANSACTION_ID) unless transaction_id = G.op.__transaction_id

      payload = {call: "transaction", transaction_id: transaction_id}.to_json

      body = rpc(node, payload)
      json = JSON.parse(body)

      if G.op.__json
        puts body
      else
        case json["status"].as_s
        when "accepted"
          puts_success(I18n.translate("sushi.cli.transaction.transaction.messages.accepted"))
          puts body
        when "pending"
          puts_success(I18n.translate("sushi.cli.transaction.transaction.messages.pending"))
        when "rejected"
          puts_error(I18n.translate("sushi.cli.transaction.transaction.messages.rejected", {reason: json["reason"].as_s}))
        when "not found"
          puts_error(I18n.translate("sushi.cli.transaction.transaction.messages.not_found"))
        else
          puts_error(I18n.translate("sushi.cli.transaction.transaction.messages.unknown"))
        end
      end
    end

    def fees
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node

      payload = {call: "fees"}.to_json

      body = rpc(node, payload)
      json = JSON.parse(body)

      if G.op.__json
        puts body
      else
        puts_success(I18n.translate("sushi.cli.transaction.fees.messages.fees"))

        puts_info("  + %30s - %30s +" % ["-" * 30, "-" * 30])
        puts_info("  | %30s | %30s |" % ["action", "fee"])
        puts_info("  | %30s | %30s |" % ["-" * 30, "-" * 30])

        json.as_h.each do |action, fee|
          puts_info("  | %30s | %30s |" % [action, fee])
        end

        puts_info("  + %30s - %30s +" % ["-" * 30, "-" * 30])
        puts_info("")
      end
    end
  end
end
