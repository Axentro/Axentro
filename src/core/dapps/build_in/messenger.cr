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

module ::Axentro::Core::DApps::BuildIn
  class Messenger < DApp
    def setup
    end

    def transaction_actions : Array(String)
      [] of String
    end

    def transaction_related?(action : String) : Bool
      false
    end

    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      ValidatedTransactions.passed(transactions)
    end

    def record(chain : Blockchain::Chain)
    end

    def clear
    end

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
      nil
    end

    def on_message(action : String, from_address : String, content : String, from = nil) : Bool
      return false unless action == "message"

      _m_content = MContentClientMessage.from_json(content)

      to = _m_content.to
      message = _m_content.message

      node.send_content_to_client(from_address, to, message, from)
    end
  end
end
