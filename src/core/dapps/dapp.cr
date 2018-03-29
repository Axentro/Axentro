module ::Sushi::Core::DApps
  abstract class DApp
    abstract def setup
    abstract def transaction_actions : Array(String)
    abstract def transaction_related?(action : String) : Bool
    abstract def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
    abstract def record(chain : Models::Chain)
    abstract def clear
    abstract def rpc?(
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
        raise "not enough fee, should be #{sender[:fee]} >= #{self.class.fee(transaction.action)}"
      end

      valid_transaction?(transaction, prev_transactions)
    end

    #
    # Default fee is 1 SHARI
    # All thrid party dApps cannot override here.
    # Otherwise the transactions will be rejected from other nodes.
    #
    def self.fee(action : String) : Int64
      1_i64
    end

    private def blockchain : Blockchain
      @blockchain
    end

    private def node : Node
      @blockchain.node
    end

    include Logger
  end
end

require "./build_in"
require "../../../dapps/*"
