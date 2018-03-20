module ::Sushi::Core::Controllers
  class RPCController < Controller
    def exec_internal_post(json, context, params) : HTTP::Server::Context
      call = json["call"].to_s

      case call
      when "create_unsigned_transaction"
        return create_unsigned_transaction(json, context, params)
      when "create_transaction"
        return create_transaction(json, context, params)
      end

      @blockchain.dapps.each do |dapp|
        next unless res_context = dapp.rpc?(call, json, context, params)
        return res_context
      end

      unpermitted_call(call, context)
    end

    def exec_internal_get(context, params) : HTTP::Server::Context
      unpermitted_method(context)
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

    def create_unsigned_transaction(json, context, params)
      action = json["action"].to_s
      senders = Models::Senders.from_json(json["senders"].to_json)
      recipients = Models::Recipients.from_json(json["recipients"].to_json)
      message = json["message"].to_s

      transaction = @blockchain.create_unsigned_transaction(
        action,
        senders,
        recipients,
        message,
      )

      fee = transaction.calculate_fee

      raise "invalid fee #{fee} for the action #{action}" if fee <= 0.0

      context.response.print transaction.to_json
      context
    end

    def unpermitted_call(call, context) : HTTP::Server::Context
      context.response.status_code = 403
      context.response.print "unpermitted call: #{call}"
      context
    end
  end
end
