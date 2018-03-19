module ::Sushi::Core
  abstract class DApp
    abstract def actions : Array(String)
    abstract def related?(action : String) : Bool
    abstract def valid_impl?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
    abstract def record(chain : Models::Chain)
    abstract def clear
    abstract def fee(action : String) : Int64
    abstract def rpc?(call : String, json : JSON::Any, context : HTTP::Server::Context, params : Hash(String, String)) : HTTP::Server::Context?

    def valid?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      raise "senders have to be only one currently" if transaction.senders.size != 1
      sender = transaction.senders[0]

      if sender[:fee] < fee(transaction.action)
        raise "not enough fee, should be #{sender[:fee]} >= #{fee(transaction.action)}"
      end

      valid_impl?(transaction, prev_transactions)
    end

    def self.fee(action : String) : Int64
      self.new.fee(action)
    end
  end
end

require "./*"
require "./dapps/*"
