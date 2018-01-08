module ::Garnet::Core::Controllers

  class RPCController < Controller

    def exec_internal_post(json, context, params) : HTTP::Server::Context
      call = json["call"].to_s

      case call
      when "create_unsigned_transaction"
        return create_unsigned_transaction(json, context, params)
      when "create_transaction"
        return create_transaction(json, context, params)
      when "remaining_amounts"
        return remaining_amounts(json, context, params)
      end

      unpermitted_call(call, context)
    end

    def exec_internal_get(context, params) : HTTP::Server::Context
      unpermitted_method(context)
    end

    def create_transaction(json, context, params)
      transaction = Transaction.from_json(json["transaction"].to_s)

      unless transaction.valid?(@blockchain, @blockchain.last_index, false)
        context.response.status_code = 403
        context.response.print "Invalid transaction"
        return context
      end

      node.broadcast_transaction(transaction)

      context.response.print transaction.to_json
      context
    end

    def create_unsigned_transaction(json, context, params)
      action = json["action"].to_s
      senders = Models::Senders.from_json(json["senders"].to_s)
      recipients = Models::Recipients.from_json(json["recipients"].to_s)
      content_hash = json["content_hash"].to_s

      transaction = @blockchain.create_unsigned_transaction(
        action,
        senders,
        recipients,
        content_hash,
      )

      fee = transaction.calculate_fee

      raise "Invalid fee #{fee} for the action #{action}" if fee <= 0.0

      context.response.print transaction.to_json
      context
    end

    def remaining_amounts(json, context, params)
      address = json["address"].to_s
      unconfirmed = json["unconfirmed"].as_bool

      amount = unconfirmed ?
                 @blockchain.get_amount_unconfirmed(address) :
                 @blockchain.get_amount(address)

      context.response.print amount.to_s
      context
    end

    def unpermitted_call(call, context) : HTTP::Server::Context
      context.response.status_code = 403
      context.response.print "Unpermitted call: #{call}"
      context
    end

    include Fees
    include Common::Num
  end
end
