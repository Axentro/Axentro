module ::Sushi::Core::DApps::BuildIn
  class Token < DApp
    getter tokens : Array(String) = ["SHARI"]

    @latest_recorded_index = 0

    def actions : Array(String)
      ["create_token"]
    end

    def related?(action : String) : Bool
      action == "create_token"
    end

    def valid_impl?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      raise "number of specified senders must be one for 'create_token'" if transaction.senders.size != 1
      raise "number of specified recipients must be one for 'create_token'" if transaction.recipients.size != 1

      sender = transaction.senders[0]
      sender_address = sender[:address]
      sender_amount = sender[:amount]

      recipient = transaction.recipients[0]
      recipient_address = recipient[:address]
      recipient_amount = recipient[:amount]

      raise "address mismatch for 'create_token'. " +
            "sender: #{sender_address}, recipient: #{recipient_address}" if sender_address != recipient_address

      raise "amount mismatch for 'create_token'. " +
            "sender: #{sender_amount}, recipient: #{recipient_amount}" if sender_amount != recipient_amount

      token = transaction.token

      raise "invalid token name: #{token}" unless valid_token_name?(token)

      raise "the token #{token} is already created" if @tokens.includes?(token)

      prev_transactions.each do |prev_transaction|
        raise "the token #{token} is already created" if prev_transaction.token == token
      end

      true
    end

    def self.valid_token_name?(token : String) : Bool
      unless token =~ /^[A-Z0-9]{1,20}$/
        token_rule = <<-RULE
You token '#{token}' is not valid

1. token name must contain only uppercase letters or numbers
2. token name length must be between 1 and 20 characters
RULE
        raise token_rule
      end

      true
    end

    def valid_token_name?(token : String) : Bool
      Token.valid_token_name?(token)
    end

    def record(chain : Models::Chain)
      return if chain.size < @latest_recorded_index

      chain[@latest_recorded_index..-1].each do |block|
        block.transactions.each do |transaction|
          next unless transaction.action == "create_token"

          address = transaction.senders[0][:address]
          amount = transaction.senders[0][:amount]
          token = transaction.token

          if !@tokens.includes?(transaction.token)
            @tokens << transaction.token

            blockchain.utxo.create_token(address, amount, token)
          end
        end
      end

      @latest_recorded_index = chain.size
    end

    def clear
      @tokens.clear
      @tokens << "SHARI"
    end

    def rpc?(call, json, context, params)
      case call
      when "token_list"
        return list(json, context, params)
      end

      nil
    end

    def list(json, context, params)
      context.response.print @tokens.to_json
      context
    end

    def self.fee(action : String) : Int64
      1000_i64
    end
  end
end
