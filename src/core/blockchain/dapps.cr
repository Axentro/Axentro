module ::Sushi::Core
  # todo: move directory
  abstract class DApp
    abstract def actions : Array(String)
    abstract def related?(action : String) : Bool
    abstract def valid_impl?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
    abstract def record(chain : Models::Chain)
    abstract def clear
    abstract def rpc?(call : String, json : JSON::Any, context : HTTP::Server::Context, params : Hash(String, String)) : HTTP::Server::Context?

    def initialize(@blockchain : Blockchain)
    end

    def valid?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      raise "senders have to be only one currently" if transaction.senders.size != 1
      sender = transaction.senders[0]

      if sender[:fee] < self.class.fee(transaction.action)
        raise "not enough fee, should be #{sender[:fee]} >= #{self.class.fee(transaction.action)}"
      end

      valid_impl?(transaction, prev_transactions)
    end

    def self.fee(action : String) : Int64
      0_i64
    end

    private def blockchain : Blockchain
      @blockchain
    end
  end
end

require "./*"
require "./dapps/*"
