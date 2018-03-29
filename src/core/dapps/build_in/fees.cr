module ::Sushi::Core::DApps::BuildIn
  class Fees < DApp
    def setup
    end

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
      case call
      when "fees"
        return fees(json, context, params)
      end

      nil
    end

    def fees(json, context, params)
      fees = Hash(String, Int64).new

      blockchain.dapps.each do |dapp|
        dapp.actions.each do |action|
          fees[action] = dapp.class.fee(action) if dapp.class.fee(action) > 0
        end
      end

      context.response.print fees.to_json
      context
    end
  end
end
