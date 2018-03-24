#
# An example for SushiChain's dApps
#
# - Create your token
#
#   In this example, we will create another token on SushiChain.
#   We name the new token as "MAGURO".
#   You can copy this file to create your own new token.
#   Rename the all token names in this file then.
#
# MEMO:
# 1. create a "create_maguro" from the cli
# 2. then, where the first tokens coming from?
#    if I create a transaction like this
#
#    - action: "create_maguro"
#    - price: is amount
#    - sender: me (with fees)
#    - recipient: me
#    - token: MAGURO
#
#    UTXO will not record the amount into the account, so we cannot use(send) them.
#
module ::Sushi::Core::DApps::User
  class CreateToken < DApp
    # The token name
    TOKEN = "MAGURO"

    @token_is_created = false
    @lastest_block_index = 0

    def actions : Array(String)
      [
        "create_maguro",
      ]
    end

    def related?(action : String) : Bool
      action == "create_maguro"
    end

    def valid_impl?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      raise "the token is already created " if @token_is_created

      prev_transactions.each do |prev_transaction|
        raise "the token is already created" if prev_transaction.action == "create_maguro"
      end

      true
    end

    def record(chain : Models::Chain)
      return if @token_is_created
      return if chain.size < @latest_block_index

      chain[@latest_block_index..-1].each do |block|
        block.transactions.each do |transaction|
          if transaction.action == "create_maguro"
            @token_is_created = true
            break
          end
        end
      end

      @latest_block_index = chain.size
    end

    def clear
      @token_is_created = false
      @latest_block_index = 0
    end

    def rpc?(call, json, context, params)
      nil
    end
  end
end
