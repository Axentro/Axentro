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

    def record_reject(transaction_id : String, e : Exception)
      error_message = e.message ? e.message.not_nil! : "unknown"
      @rejects[transaction_id] ||= error_message
    end

    def record(chain : Models::Chain)
    end

    def clear
    end

    def fee(action : String) : Int64
      0_i64
    end

    def find?(transaction_id : String) : String?
      @rejects[transaction_id]?
    end
  end
end
