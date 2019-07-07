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
          name: "create",
          desc: "create a transaction, generally used for sending tokens but you can specify other actions. (the default action is 'send')",
        },
        {
          name: "transactions",
          desc: "get transactions in a specified block or for an address (txs for short)",
        },
        {
          name: "transaction",
          desc: "get a transaction for a transaction id (tx for short)",
        },
        {
          name: "confirmation",
          desc: "get the number of confirmations (cf for short)",
        },
        {
          name: "fees",
          desc: "show fees for each action",
        },
      ]
    end

    def option_parser
      G.op.create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
        Options::CONFIRMATION,
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
      ])
    end

    def run_impl(action_name)
      case action_name
      when "create"
        return create
      when "transactions", "txs"
        return transactions
      when "transaction", "tx"
        return transaction
      when "confirmation", "cf"
        return confirmation
      when "fees"
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
                            resolved = resolve_internal(node, G.op.__domain.not_nil!, G.op.__confirmation)
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

      add_transaction(node, action, wallets, senders, recipients, G.op.__message, G.op.__token || TOKEN_DEFAULT)
    end

    def transactions
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_BLOCK_INDEX_OR_ADDRESS) if G.op.__block_index.nil? && G.op.__address.nil?

      payload = if block_index = G.op.__block_index
                  success_message = "show transactions in a block #{block_index}"
                  {call: "transactions", index: block_index}.to_json
                elsif address = G.op.__address
                  success_message = "show transactions for an address #{address}"
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
          puts_success("show the transaction")
          puts body
        when "pending"
          puts_success("the transaction is still pending in transaction pool")
        when "rejected"
          puts_error("the transaction was rejected. " +
                     "the reason: #{json["reason"].as_s}")
        when "not found"
          puts_error("the transaction was not found")
        else
          puts_error("unknown status for the transaction")
        end
      end
    end

    def confirmation
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_TRANSACTION_ID) unless transaction_id = G.op.__transaction_id

      payload = {call: "confirmation", transaction_id: transaction_id}.to_json

      body = rpc(node, payload)

      if G.op.__json
        puts body
      else
        puts_success("show the number of confirmations of #{transaction_id}")

        json = JSON.parse(body)

        puts_info("transaction id: #{transaction_id}")
        puts_info("--------------")
        puts_info("confirmations: #{json["confirmations"]}")
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
        puts_success("\n  showing fees for each action.\n")

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
