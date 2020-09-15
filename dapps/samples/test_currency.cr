# Copyright © 2017-2018 The Axentro Core developers
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
  class TestCurrency < UserDApp
    def valid_addresses : Array(String)
      [] of String
    end

    def valid_networks : Array(String)
      ["testnet"]
    end

    def related_transaction_actions : Array(String)
      [] of String
    end

    def valid_transaction?(transaction, prev_transactions) : Bool
      true
    end

    def activate : Int64?
      nil
    end

    def deactivate : Int64?
      nil
    end

    def new_block(block)
    end

    def tx_id(transaction)
      sha256(transaction.to_hash)
    end

    def define_rpc?(call, json, context) : HTTP::Server::Context?
      if call == "currency"
        sender = create_sender("500")
        address = json["address"].as_s
        recipient = create_recipient(address, "500")

        transaction_id = Transaction.create_id

        created = create_transaction(
          transaction_id,       # id
          "send",               # action
          sender,               # sender
          recipient,            # recipient
          "",                   # message
          TOKEN_DEFAULT,        # token
          TransactionKind::FAST # kind
        )

        info "created a transaction from TestCurrency(UserDApp): #{transaction_id}" if created
        return context
      end

      nil
    end
  end
end
