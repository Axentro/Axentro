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
      
    end

    def clear
    end

    def rpc?(call, json, context, params)
    end
  end
end
