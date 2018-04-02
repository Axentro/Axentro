module ::Sushi::Core::DApps::BuildIn
  class Fees < DApp
    def setup
    end

    def transaction_actions : Array(String)
      [] of String
    end

    def transaction_related?(action : String) : Bool
      false
    end

    def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      true
    end

    def record(chain : Models::Chain)
    end

    def clear
    end

    def define_rpc?(call, json, context, params)
      case call
      when "fees"
        return fees(json, context, params)
      end

      nil
    end

    def fees(json, context, params)
      fees = Hash(String, Int64).new

      blockchain.dapps.each do |dapp|
        dapp.transaction_actions.each do |action|
          fees[action] = dapp.class.fee(action) if dapp.class.fee(action) > 0
        end
      end

      context.response.print fees.to_json
      context
    end
  end
end
