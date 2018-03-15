module ::Sushi::Core::Controllers
  class RPCController < Controller
    def exec_internal_post(json, context, params) : HTTP::Server::Context
      call = json["call"].to_s

      case call
      when "create_unsigned_transaction"
        return create_unsigned_transaction(json, context, params)
      when "create_transaction"
        return create_transaction(json, context, params)
      when "amount"
        return amount(json, context, params)
      when "blockchain_size"
        return blockchain_size(json, context, params)
      when "blockchain"
        return blockchain(json, context, params)
      when "block"
        return block(json, context, params)
      when "transactions"
        return transactions(json, context, params)
      when "transaction"
        return transaction(json, context, params)
      when "confirmation"
        return confirmation(json, context, params)
      when "scars_resolve"
        return scars_resolve(json, context, params)
      when "scars_for_sale"
        return scars_for_sale(json, context, params)
      end

      unpermitted_call(call, context)
    end

    def exec_internal_get(context, params) : HTTP::Server::Context
      unpermitted_method(context)
    end

    def scars_resolve(json, context, params)
      domain_name = json["domain_name"].as_s
      confirmed = json["confirmed"].as_bool

      domain = confirmed ? @blockchain.scars.resolve(domain_name) : @blockchain.scars.resolve_unconfirmed(domain_name, [] of Transaction)

      response = if domain
                   {resolved: true, domain: domain}.to_json
                 else
                   default_domain = {domain_name: domain_name, address: "", status: Models::DomainStatus::NotFound, price: 0}
                   {resolved: false, domain: default_domain}.to_json
                 end

      context.response.print response
      context
    end

    def scars_for_sale(json, context, params)
      domain_for_sale = @blockchain.scars.sales

      context.response.print domain_for_sale.to_json
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

    def amount(json, context, params)
      address = json["address"].to_s
      unconfirmed = json["unconfirmed"].as_bool

      amount = unconfirmed ? @blockchain.utxo.get_unconfirmed(address, [] of Transaction) : @blockchain.utxo.get(address)

      json = {amount: amount, address: address, unconfirmed: unconfirmed}.to_json

      context.response.print json
      context
    end

    def blockchain_size(json, context, params)
      size = @blockchain.chain.size

      json = {size: size}.to_json
      context.response.print json
      context
    end

    def blockchain(json, context, params)
      if json["header"].as_bool
        context.response.print @blockchain.headers.to_json
      else
        context.response.print @blockchain.chain.to_json
      end

      context
    end

    def block(json, context, params)
      block = if index = json["index"]?
                if index.as_i > @blockchain.chain.size - 1
                  raise "invalid index #{index} (Blockchain size is #{@blockchain.chain.size})"
                end

                @blockchain.chain[index.as_i]
              elsif transaction_id = json["transaction_id"]?
                unless block_index = @blockchain.indices.get(transaction_id.to_s)
                  raise "failed to find a block for the transaction #{transaction_id}"
                end

                @blockchain.chain[block_index]
              else
                raise "please specify block index or transaction id"
              end

      if json["header"].as_bool
        context.response.print block.to_header.to_json
      else
        context.response.print block.to_json
      end

      context
    end

    def transactions(json, context, params)
      if index = json["index"]?
        if index.as_i > @blockchain.chain.size - 1
          raise "invalid index #{index.as_i} (Blockchain size is #{@blockchain.chain.size})"
        end
        context.response.print @blockchain.chain[index.as_i].transactions.to_json
      elsif address = json["address"]?
        transactions = @blockchain.transactions_for_address(address.as_s)
        context.response.print transactions.to_json
      else
        raise "please specify a block index or an address"
      end

      context
    end

    def transaction(json, context, params)
      transaction_id = json["transaction_id"].as_s

      unless block_index = @blockchain.indices.get(transaction_id)
        raise "failed to find a block for the transaction #{transaction_id}"
      end

      unless transaction = @blockchain.chain[block_index].find_transaction(transaction_id)
        raise "failed to find a transaction for #{transaction_id}"
      end

      context.response.print transaction.to_json
      context
    end

    def confirmation(json, context, params)
      transaction_id = json["transaction_id"].as_s

      unless block_index = @blockchain.indices.get(transaction_id)
        raise "failed to find a block for the transaction #{transaction_id}"
      end

      latest_index = @blockchain.chain[-1].index

      result = {
        confirmed:     (latest_index - block_index) >= UTXO::CONFIRMATION,
        confirmations: latest_index - block_index,
        threshold:     UTXO::CONFIRMATION,
      }.to_json

      context.response.print result
      context
    end

    def unpermitted_call(call, context) : HTTP::Server::Context
      context.response.status_code = 403
      context.response.print "unpermitted call: #{call}"
      context
    end
  end
end
