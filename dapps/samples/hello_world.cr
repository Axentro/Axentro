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

# An example for Axentro's dApps
#
# - Hello World!
#
#   It just show a message "Hello world! from Axentro :)"
#   Execute following command
#   ```
#   curl -XPOST http://[your node]/rpc -d "{\"call\": \"hello\"}"
#   ```
#
module ::Axentro::Core::DApps::User
  class HelloWorld < UserDApp
    def valid_addresses : Array(String)
      [] of String
    end

    def valid_networks : Array(String)
      ["testnet"]
    end

    def related_transaction_actions : Array(String)
      [] of String
    end

    # def valid_transaction?(transaction, prev_transactions) : Bool
    #   true
    # end

    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      ValidatedTransactions.empty
    end

    def activate : Int64?
      nil
    end

    def deactivate : Int64?
      nil
    end

    def new_block(block)
    end

    def define_rpc?(call, json, context) : HTTP::Server::Context?
      if call == "hello"
        context.response.print "Hello World from Axentro! :)"
        return context
      end

      nil
    end
  end
end
