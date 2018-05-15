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

module ::Sushi::Core::DApps
  abstract class DApp
    extend Common::Denomination

    abstract def setup
    abstract def transaction_actions : Array(String)
    abstract def transaction_related?(action : String) : Bool
    abstract def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
    abstract def record(chain : Blockchain::Chain)
    abstract def clear
    abstract def define_rpc?(
      call : String,
      json : JSON::Any,
      context : HTTP::Server::Context,
      params : Hash(String, String)
    ) : HTTP::Server::Context?

    def initialize(@blockchain : Blockchain)
    end

    def valid?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      raise "senders have to be only one currently" if transaction.senders.size != 1
      sender = transaction.senders[0]

      if sender[:fee] < self.class.fee(transaction.action)
        raise "not enough fee, should be #{scale_decimal(sender[:fee])} >= #{scale_decimal(self.class.fee(transaction.action))}"
      end

      valid_transaction?(transaction, prev_transactions)
    end

    #
    # Default fee is 0.0001 SUSHI
    # All thrid party dApps cannot override here.
    # Otherwise the transactions will be rejected from other nodes.
    #
    def self.fee(action : String) : Int64
      scale_i64("0.0001")
    end

    private def blockchain : Blockchain
      @blockchain
    end

    private def node : Node
      @blockchain.node
    end

    include Logger
    include NodeComponents::APIFormat
    include Common::Denomination
  end
end

require "./build_in"
require "../../../dapps/dapps"
