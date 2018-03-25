#
# Transaction structure
#
# - action: "create_token"
# - senders:
#     address: deposit address
#     amount: first deposit amount
#     fee: 1000
# - recipients:
#     address: deposit address
#     amount: first deposit amount
# - message: Ignored
# - token: token name
#
# todo: create a cli
#
module ::Sushi::Core::DApps::BuildIn
  class Token < DApp
    @tokens : Array(String) = ["SHARI"]

    def actions : Array(String)
      ["create_token"]
    end

    def related?(action : String) : Bool
      action == "create_token"
    end

    def valid_impl?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      raise "sender must be one for 'create_token'" if transaction.senders.size != 1
      raise "recipient must  be one for 'create_token'" if transaction.recipients.size != 1

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

    # todo
    def self.valid_token_name?(token : String) : Bool
      true
    end

    def valid_token_name?(token : String) : Bool
      Token.valid_token_name?(token)
    end

    def record(chain : Models::Chain)
      chain.each do |block|
        block.transactions.each do |transaction|
          next unless transaction.action == "create_token"

          address = transaction.senders[0][:address]
          amount = transaction.senders[0][:amount]
          token = transaction.token

          puts "--- create token"
          puts "    address: #{address}"
          puts "    amount:  #{amount}"
          puts "    token:   #{token}"

          if !@tokens.includes?(transaction.token)
            @tokens << transaction.token

            # todo: check
            blockchain.utxo.create_token(address, amount, token)
          end
        end
      end
    end

    def clear
      @tokens.clear
    end

    def rpc?(call, json, context, params)
      case call
      when "list"
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
