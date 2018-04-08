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

# An example for SushiChain's dApps
#
# - Hello World!
#
#   It just show a message "Hello world! from SushiChain :)"
#   Execute following command
#   ```
#   curl -XPOST http://[your node]/rpc -d "{\"call\": \"hello\"}"
#   ```
#
module ::Sushi::Core::DApps::User
  class HelloWorld < UserDApp
    def valid_addresses
      [] of String
    end

    def valid_networks
      ["testnet"]
    end

    def related_transaction_actions
      [] of String
    end

    def valid_transaction?(transaction, prev_transactions)
      true
    end

    def new_block(block)
    end

    def define_rpc?(call, json, context)
      if call == "hello"
        context.response.print "Hello World from SushiChain! :)"
        return context
      end

      nil
    end
  end
end
