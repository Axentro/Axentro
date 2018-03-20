module ::Sushi::Core
  class Rejects < DApp
    @rejects : Hash(String, String) = Hash(String, String).new

    def actions : Array(String)
      [] of String
    end

    def related?(action : String) : Bool
      true
    end

    def valid_impl?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      true
    end

    # todo: can we remove this method?
    def record_reject(transaction_id : String, e : Exception)
      error_message = e.message ? e.message.not_nil! : "unknown"
      @rejects[transaction_id] ||= error_message
    end

    def record(chain : Models::Chain)
      # todo: think about this
    end

    def clear
      @rejects.clear
    end

    def rpc?(call, json, context, params)
      case call
      when "rejects"
        return rejects?(json, context, params)
      end

      nil
    end

    def rejects?(json, context, params)
      transaction_id = json["transaction_id"].as_s

      result = if rejected_reason = @rejects[transaction_id]?
                 {
                   rejected: true,
                   reason: rejected_reason,
                 }
               else
                 {
                   rejected: false,
                   reason: "",
                 }
               end

      context.response.print result.to_json
      context
    end
  end
end
