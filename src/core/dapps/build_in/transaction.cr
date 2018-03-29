module ::Sushi::Core::DApps::BuildIn
  class TransactionCreator < DApp
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

    def rpc?(call, json, context, params)
      case call
      when "create_unsigned_transaction"
        return create_unsigned_transaction(json, context, params)
      when "create_transaction"
        return create_transaction(json, context, params)
      end

      nil
    end

    def create_unsigned_transaction(json, context, params)
      action = json["action"].as_s
      senders = Models::Senders.from_json(json["senders"].to_json)
      recipients = Models::Recipients.from_json(json["recipients"].to_json)
      message = json["message"].as_s
      token = json["token"].as_s

      transaction = blockchain.create_unsigned_transaction(
        action,
        senders,
        recipients,
        message,
        token,
      )

      fee = transaction.calculate_fee

      raise "invalid fee #{fee} for the action #{action}" if fee <= 0.0

      context.response.print transaction.to_json
      context
    end

    def create_transaction(json, context, params)
      transaction = Transaction.from_json(json["transaction"].to_json)

      node.broadcast_transaction(transaction)

      context.response.print transaction.to_json
      context
    rescue e : Exception
      context.response.status_code = 403
      context.response.print e.message.not_nil!
      context      
    end
  end
end
