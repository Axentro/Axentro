module ::Sushi::Core::DApps::BuildIn
  class BlockchainInfo < DApp
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
      when "blockchain_size"
        return blockchain_size(json, context, params)
      when "blockchain"
        return blockchain(json, context, params)
      when "block"
        return block(json, context, params)
      when "transactions"
        return transactions(json, context, params)
      end

      nil
    end

    def blockchain_size(json, context, params)
      size = blockchain.chain.size

      json = {size: size}.to_json

      context.response.print json
      context
    end

    def blockchain(json, context, params)
      if json["header"].as_bool
        context.response.print blockchain.headers.to_json
      else
        context.response.print blockchain.chain.to_json
      end

      context
    end

    def block(json, context, params)
      block = if index = json["index"]?
                if index.as_i > blockchain.chain.size - 1
                  raise "invalid index #{index} (Blockchain size is #{blockchain.chain.size})"
                end

                blockchain.chain[index.as_i]
              elsif transaction_id = json["transaction_id"]?
                unless block_index = blockchain.indices.get(transaction_id.to_s)
                  raise "failed to find a block for the transaction #{transaction_id}"
                end

                blockchain.chain[block_index]
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
        if index.as_i > blockchain.chain.size - 1
          raise "invalid index #{index.as_i} (Blockchain size is #{blockchain.chain.size})"
        end
        context.response.print blockchain.chain[index.as_i].transactions.to_json
      elsif address = json["address"]?
        transactions = blockchain.transactions_for_address(address.as_s)
        context.response.print transactions.to_json
      else
        raise "please specify a block index or an address"
      end

      context
    end
  end
end
