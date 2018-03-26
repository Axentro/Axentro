#
# An example for SushiChain's dApps
#
# - Send token
#
#   A behavior of this example is like this;
#
#   "If you send a token AAA (amount: 100) to BBB I send a token CCC (amount: 100) to DDD"
#
module ::Sushi::Core::DApps::User
  class SendToken < DApp
    FOUNDER_ADDRESS = "VDA5OWRhYzY5NzExNTdkMWI0ZDE0NWE4NTg5M2EzNzM5ODQ1ZjdhZGYyMzMzNjI1"

    @latest_recorded_index = 0

    def actions : Array(String)
      [] of String
    end
 
    def related?(action : String) : Bool
      false
    end

    def valid_impl?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      true
    end

    def record(chain : Models::Chain)
      return if chain.size < @latest_recorded_index

      chain[@latest_recorded_index..-1].map { |block| block.transactions }.flatten
        .select { |transaction|
          transaction.action == "send" && 
          transaction.token == "SHARI" &&
          transaction.senders.size == 1 &&
          transaction.recipients.size == 1 &&
          transaction.recipients[0][:address] == FOUNDER_ADDRESS &&
          transaction.senders[0][:amount] == 100
      }

      # blockchain.node.broadcast_transaction()
      # todo: a way to sign

      @latest_recorded_index = chain.size
    end

    def clear
    end

    def rpc?(call, json, context, params)
    end
  end
end
