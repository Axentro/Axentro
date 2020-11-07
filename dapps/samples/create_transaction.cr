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

module ::Axentro::Core::DApps::User
  class CreateTransaction < UserDApp
    #
    # The target action name in transaction's field
    #
    TARGET_ACTION = "create_transaction_sample"

    #
    # The address is from wallets/testnet-0.json
    #
    VALID_ADDRESS = "VDAxMjJmMTcyNWE1NmE0MjExZTk0ZThkMGRiYmM2ZjE1YTQ5OWRmODM1MzliYmUy"

    def valid_addresses : Array(String)
      [VALID_ADDRESS]
    end

    def valid_networks : Array(String)
      ["testnet"]
    end

    def related_transaction_actions : Array(String)
      [TARGET_ACTION]
    end

    private def validate_transaction(transaction : Transaction)
      raise "the token must be #{TOKEN_DEFAULT}" unless transaction.token == TOKEN_DEFAULT
      raise "the number of senders must be 1" unless transaction.senders.size == 1
      raise "the number of recipients must be 1" unless transaction.recipients.size == 1
      raise "the recipient address must be #{VALID_ADDRESS}" unless transaction.recipients[0][:address] == VALID_ADDRESS
      raise "the sending amount must be 0.0001" unless transaction.senders[0][:amount] == scale_i64("0.0001")
    end

    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      vt = ValidatedTransactions.empty
      transactions.each do |transaction|
        validate_transaction(transaction)
        vt << transaction.as_validated
      rescue e : Exception
        vt << FailedTransaction.new(transaction, e.message || "unknown error", "create_transaction").as_validated
      end
      vt
    end

    def activate : Int64?
      nil
    end

    def deactivate : Int64?
      nil
    end

    def new_block(block)
      block.transactions.each do |transaction|
        if transaction.action == TARGET_ACTION
          info "found a #{TARGET_ACTION} transaction"

          sender = create_sender("0.00005")
          recipient = create_recipient(transaction.senders[0][:address], "0.00005")
          #
          # You can create a transaction id by `create_transaction_id`
          #
          # If you create it manually, note that every node must create same id for an action.
          # Otherwise, all duplicated transactions for 1 action will be accepted,
          # if you run the dApp on multiple nodes.
          #
          # `sha256` is useful method to create an id.
          #
          id = create_transaction_id(block, transaction)

          created = create_transaction(
            id,                                                               # id
            "send",                                                           # action
            sender,                                                           # sender
            recipient,                                                        # recipient
            "Thanks for sending me 0.0001 AXNT! I'll back you 0.00005 AXNT!", # message
            TOKEN_DEFAULT,                                                    # token
            TransactionKind::SLOW                                             # kind
          )

          info "created a transaction from CreateTranscation(UserDApp): #{id}" if created
        end
      end
    end

    def define_rpc?(call, json, context) : HTTP::Server::Context?
      nil
    end
  end
end
