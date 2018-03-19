module ::Sushi::Core
  class Indices < DApp
    @indices : Array(Hash(String, Int64)) = Array(Hash(String, Int64)).new

    def get(transaction_id : String) : Int64?
      @indices.reverse.each do |indices|
        return indices[transaction_id] if indices[transaction_id]?
      end

      nil
    end

    def actions : Array(String)
      [] of String
    end

    def related?(action : String) : Bool
      true
    end

    def valid_impl?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      true
    end

    def record(chain : Models::Chain)
      return if @indices.size >= chain.size

      chain[@indices.size..-1].each do |block|
        @indices.push(Hash(String, Int64).new)

        block.transactions.each do |transaction|
          @indices[-1][transaction.id] = block.index
        end
      end
    end

    def clear
      @indices.clear
    end

    def fee(action : String) : Int64
      0_i64
    end

    def rpc?(call, json, context, params)
      case call
      when "transaction"
        return transaction(json, context, params)
      when "confirmation"
        return confirmation(json, context, params)
      end

      nil
    end

    def transaction(json, context, params)
      transaction_id = json["transaction_id"].as_s

      # todo
      # if rejected_reason = @blockchain.rejects.find?(transaction_id)
      #   raise "the transaction was rejected for the reason '#{rejected_reason}'"
      # end

      unless block_index = get(transaction_id)
        raise "failed to find a block for the transaction #{transaction_id}"
      end

      # todo
      # think about this
      unless transaction = @blockchain.chain[block_index].find_transaction(transaction_id)
        raise "failed to find a transaction for #{transaction_id}"
      end

      context.response.print transaction.to_json
      context
    end

    def confirmation(json, context, params)
      transaction_id = json["transaction_id"].as_s

      unless block_index = get(transaction_id)
        raise "failed to find a block for the transaction #{transaction_id}"
      end

      latest_index = @indices.size

      result = {
        confirmed:     (latest_index - block_index) >= UTXO::CONFIRMATION,
        confirmations: latest_index - block_index,
        threshold:     UTXO::CONFIRMATION,
      }.to_json

      context.response.print result
      context
    end
  end
end
