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
          desc: "create a transaction. basically it's used for sending tokens. you can specify other actions. (the default action is 'send')",
        },
        {
          name: "transactions",
          desc: "get trasactions in a specified block or for an address (txs for short)",
        },
        {
          name: "transaction",
          desc: "get a transaction for a transaction id (tx for short)",
        },
        {
          name: "confirmation",
          desc: "get a number of confirmations (cf for short)",
        },
        {
          name: "fees",
          desc: "show fees for each action",
        },
      ]
    end

    def option_parser
      create_option_parser([
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
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = __wallet_path
      puts_help(HELP_AMOUNT) unless amount = __amount
      puts_help(HELP_FEE) unless fee = __fee
      puts_help(HELP_ADDRESS_DOMAIN_RECIPIENT) if __address.nil? && __domain.nil?

      action = __action || "send"

      recipient_address = if address = __address
                            address
                          else
                            resolved = resolve_internal(node, __domain.not_nil!, __confirmation)
                            raise "domain #{__domain.not_nil!} is not resolved" unless resolved["resolved"].as_bool
                            resolved["domain"]["address"].as_s
                          end

      to_address = Address.from(recipient_address, "recipient")

      wallet = get_wallet(wallet_path, __wallet_password)
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

      add_transaction(node, action, wallets, senders, recipients, __message, __token || TOKEN_DEFAULT, __auth_code || "")
    end

    def transactions
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node
      puts_help(HELP_BLOCK_INDEX_OR_ADDRESS) if __block_index.nil? && __address.nil?

      payload = if block_index = __block_index
                  success_message = "show transactions in a block #{block_index}"
                  {call: "transactions", index: block_index}.to_json
                elsif address = __address
                  success_message = "show transactions for an address #{address}"
                  {call: "transactions", address: address}.to_json
                else
                  puts_help(HELP_BLOCK_INDEX_OR_ADDRESS)
                end

      body = rpc(node, payload)

      puts_success(success_message) unless __json
      puts body
    end

    def transaction
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node
      puts_help(HELP_TRANSACTION_ID) unless transaction_id = __transaction_id

      payload = {call: "transaction", transaction_id: transaction_id}.to_json

      body = rpc(node, payload)
      json = JSON.parse(body)

      unless __json
        case json["status"].as_s
        when "accepted"
          puts_success("show the transaction")
          puts body
        when "pending"
          puts_success("the transaction is still pending in transaction pool")
        when "rejected"
          puts_error("the transaction was rejected")
          puts_error("the reason: #{json["reason"].as_s}")
        when "not found"
          puts_error("the transcation was not found")
        else
          puts_error("unknown status for the transaction")
        end
      else
        puts body
      end
    end

    def confirmation
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node
      puts_help(HELP_TRANSACTION_ID) unless transaction_id = __transaction_id

      payload = {call: "confirmation", transaction_id: transaction_id}.to_json

      body = rpc(node, payload)

      unless __json
        puts_success("show the number of confirmations of #{transaction_id}")

        json = JSON.parse(body)

        puts_info("transaction id: #{transaction_id}")
        puts_info("--------------")
        puts_info("confirmations: #{json["confirmations"]}")
      else
        puts body
      end
    end

    def fees
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node

      payload = {call: "fees"}.to_json

      body = rpc(node, payload)
      json = JSON.parse(body)

      unless __json
        puts_success("\n  showing fees for each action.\n")

        puts_info("  + %30s - %30s +" % ["-" * 30, "-" * 30])
        puts_info("  | %30s | %30s |" % ["action", "fee"])
        puts_info("  | %30s | %30s |" % ["-" * 30, "-" * 30])

        json.each do |action, fee|
          puts_info("  | %30s | %30s |" % [action, fee])
        end

        puts_info("  + %30s - %30s +" % ["-" * 30, "-" * 30])
        puts_info("")
      else
        puts body
      end
    end

    include GlobalOptionParser
  end
end
