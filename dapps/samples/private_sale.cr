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
  class PrivateSale < UserDApp
    def valid_addresses : Array(String)
      [] of String
    end

    def valid_networks : Array(String)
      ["testnet"]
    end

    def related_transaction_actions : Array(String)
      [] of String
    end

    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      ValidatedTransactions.passed(transactions)
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

    def initialize(@blockchain)
      @address_time_map = {} of String => Int32
      super(@blockchain)
    end

    def define_rpc?(call, json, context) : HTTP::Server::Context?
      if call == "private_sale"
        r = Crest.post("http://localhost:9000/private_sale", form: json.as_h.to_json, headers: {"Content-Type" => "application/json"})
        if r.status_code == 200
          context.response.print(r.body)
        else
          context.response.respond_with_status(r.status_code, r.body)
        end
        context
      end
    end
  end
end
