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
  struct Reject
    getter transaction_id
    getter sender_address
    getter reason
    getter timestamp

    def initialize(@transaction_id : String, @sender_address : String, @reason : String, @timestamp : Int64); end

    def to_json(b)
      {"transaction_id" => transaction_id, "sender_address" => sender_address, "reason" => reason, "timestamp" => timestamp}.to_json
    end
  end

  class Rejects < DApp
    def setup
    end

    def self.address_from_senders(senders : Array(Sender))
      sender_list = senders.map { |s| s[:address] }
      sender_list.empty? ? "" : sender_list.first
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

    def record_reject(transaction_id : String, sender_address : String, e : Exception)
      error_message = e.message || "unknown"
      record_reject(transaction_id, sender_address, error_message)
    end

    def record_reject(transaction_id : String, sender_address : String, error_message : String)
      database.insert_reject(Reject.new(transaction_id, sender_address, error_message, __timestamp))
    end

    def record(chain : Blockchain::Chain)
    end

    def clear
    end

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
    end

    def find(transaction_id : String) : Reject?
      database.find_reject(transaction_id)
    end

    def find_by_address(address : String, limit : Int32 = 5) : Array(Reject)
      database.find_reject_by_address(address, limit)
    end

    def on_message(action : String, from_address : String, content : String, from = nil) : Bool
      false
    end
  end
end
