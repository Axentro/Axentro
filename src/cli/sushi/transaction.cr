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

      if fee < Core::DApps::BuildIn::UTXO.fee(action)
        raise "invalid fee for the action #{action}: minimum fee is #{Core::DApps::BuildIn::UTXO.fee("action")}"
      end

      recipient_address = if address = __address
                            address
                          else
                            resolved = resolve_internal(node, __domain.not_nil!)
                            raise "domain #{__domain.not_nil!} is not resolved" unless resolved["resolved"].as_bool
                            resolved["domain"]["address"].as_s
                          end

      to_address = Address.from(recipient_address, "recipient")

      wallet = get_wallet(wallet_path, __wallet_password)

      senders = Core::Transaction::Senders.new
      senders.push(
        {
          address:    wallet.address,
          public_key: wallet.public_key,
          amount:     amount,
          fee:        fee,
        }
      )

      recipients = Core::Transaction::Recipients.new
      recipients.push(
        {
          address: to_address.as_hex,
          amount:  amount,
        }
      )

      add_transaction(node, wallet, action, senders, recipients, __message, __token || TOKEN_DEFAULT)
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

      if json["found"].as_bool
        puts_success("show the transaction #{transaction_id}") unless __json
        puts body
      else
        # the transaction is not found in each block
        # try to find the rejected reason
        payload = {call: "rejects", transaction_id: transaction_id}.to_json

        body = rpc(node, payload)
        json = JSON.parse(body)

        if json["rejected"].as_bool
          puts_error "transaction #{transaction_id} was rejected for a reason:"
          puts_error json["reason"].as_s
          exit -1
        else
          puts_error "transaction #{transaction_id} was not found"
          exit -1
        end
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
        puts_info("confirmed: #{json["confirmed"]}")
        puts_info("confirmations: #{json["confirmations"]}")
        puts_info("threshold: #{json["threshold"]}")
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

        puts_info("  + %20s - %20s +" % ["-" * 20, "-" * 20])
        puts_info("  | %20s | %20s |" % ["action", "fee"])
        puts_info("  | %20s | %20s |" % ["-" * 20, "-" * 20])

        json.each do |action, fee|
          puts_info("  | %20s | %20s |" % [action, fee])
        end

        puts_info("  + %20s - %20s +" % ["-" * 20, "-" * 20])
        puts_info("")
      else
        puts body
      end
    end

    include GlobalOptionParser
  end
end
