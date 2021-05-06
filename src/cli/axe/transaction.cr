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
  class Transaction < CLI
    def sub_actions : Array(AxeAction)
      [
        {
          name: I18n.translate("axe.cli.transaction.create.title"),
          desc: I18n.translate("axe.cli.transaction.create.desc"),
        },
        {
          name: I18n.translate("axe.cli.transaction.transactions.title"),
          desc: I18n.translate("axe.cli.transaction.transactions.desc"),
        },
        {
          name: I18n.translate("axe.cli.transaction.transaction.title"),
          desc: I18n.translate("axe.cli.transaction.transaction.desc"),
        },
        {
          name: I18n.translate("axe.cli.transaction.fees.title"),
          desc: I18n.translate("axe.cli.transaction.fees.desc"),
        },
      ]
    end

    def option_parser : OptionParser?
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
        Options::IS_FAST_TRANSACTION,
      ])
    end

    def run_impl(action_name) : OptionParser?
      case action_name
      when I18n.translate("axe.cli.transaction.create.title")
        return create
      when I18n.translate("axe.cli.transaction.transactions.title"), "txs"
        return transactions
      when I18n.translate("axe.cli.transaction.transaction.title"), "tx"
        return transaction
      when I18n.translate("axe.cli.transaction.fees.title")
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
        SenderDecimal.new(wallet.address, wallet.public_key, amount, fee, "0")
      )

      recipients = RecipientsDecimal.new
      recipients.push(
        RecipientDecimal.new(to_address.as_hex, amount)
      )

      kind = G.op.__is_fast_transaction ? TransactionKind::FAST : TransactionKind::SLOW

      add_transaction(node, action, wallets, senders, recipients, [] of Transaction::Asset, [] of Transaction::Module, [] of Transaction::Input, [] of Transaction::Output, "", G.op.__message, G.op.__token || TOKEN_DEFAULT, kind)
    end

    def transactions
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_BLOCK_INDEX_OR_ADDRESS) if G.op.__block_index.nil? && G.op.__address.nil?

      payload = if block_index = G.op.__block_index
                  success_message = I18n.translate("axe.cli.transaction.transactions.messages.index", {block_index: block_index})
                  {call: "transactions", index: block_index}.to_json
                elsif address = G.op.__address
                  success_message = I18n.translate("axe.cli.transaction.transactions.messages.address", {address: address})
                  {call: "transactions", address: address}.to_json
                else
                  puts_help(HELP_BLOCK_INDEX_OR_ADDRESS)
                end

      body = rpc(node, payload)
      json = JSON.parse(body)

      puts_success(success_message) unless G.op.__json

      if G.op.__json
        puts body
      else
        table = Tallboy.table do
          columns do
            add "timestamp"
            add "token"
            add "id"
            add "action"
            add "from"
            add "to"
            add "amount"
            add "message"
            add "kind"
          end
          header
          rows json.as_a.map { |t| [t["timestamp"], t["token"], Core::Transaction.short_id(t["id"].as_s), t["action"], recipients(t["recipients"].as_a, t["action"].as_s), to(t["senders"].as_a), amount(t["recipients"].as_a), t["message"], t["kind"]] }
        end

        puts table.render
      end
    end

    private def recipients(recipients, action)
      r = recipients.map(&.["address"].as_s.strip)
      r.empty? ? "" : "#{r.first} #{for_action(action, r.size)} "
    end

    private def to(senders)
      r = senders.map(&.["address"].as_s.strip)
      r.empty? ? "" : "#{r.first} #{if_lots(r.size)} "
    end

    private def amount(recipients)
      scale_decimal(recipients.sum(&.["amount"].as_i64))
    end

    private def if_lots(size)
      size > 1 ? "(1/#{size})" : ""
    end

    private def for_action(action, size)
      if action == "head"
        if_lots(size)
      end
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
          puts_success(I18n.translate("axe.cli.transaction.transaction.messages.accepted"))

          h = json.as_h

          table = Tallboy.table do
            columns do
              add "status"
              add "timestamp"
              add "token"
              add "id"
              add "action"
              add "from"
              add "to"
              add "amount"
              add "message"
              add "kind"
              add "confirmations"
            end
            header
            rows [h["transaction"]].map { |t| [h["status"], t["timestamp"], t["token"], Core::Transaction.short_id(t["id"].as_s), t["action"], recipients(t["recipients"].as_a, t["action"].as_s), to(t["senders"].as_a), amount(t["recipients"].as_a), t["message"], t["kind"], h["confirmations"]] }
          end

          puts table.render
        when "pending"
          puts_success(I18n.translate("axe.cli.transaction.transaction.messages.pending"))
        when "rejected"
          puts_error(I18n.translate("axe.cli.transaction.transaction.messages.rejected", {reason: json["reason"].as_s}))
        when "not found"
          puts_error(I18n.translate("axe.cli.transaction.transaction.messages.not_found"))
        else
          puts_error(I18n.translate("axe.cli.transaction.transaction.messages.unknown"))
        end
      end
    end

    def fees
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node

      payload = {call: "fees"}.to_json

      body = rpc(node, payload)
      json = JSON.parse(body)

      puts_success(I18n.translate("axe.cli.transaction.fees.messages.fees"))

      if G.op.__json
        puts body
      else
        table = Tallboy.table do
          columns do
            add "action", align: :right
            add "fee", align: :right, width: 20
          end
          header
          rows json.as_h.map { |action, fee| [action, fee] }
        end

        puts table.render
      end
    end
  end
end
