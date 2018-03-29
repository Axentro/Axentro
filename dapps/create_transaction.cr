#
# An example for SushiChain's dApps
#
# - Create Transaction!
#
#   This app shows how to create transactions from dApps
#   todo: write details
#
module ::Sushi::Core::DApps::User
  class CreateTransaction < DApp
    @latest_loaded_block_index = 0

    FOUNDER_ADDRESS = "VDAxMjJmMTcyNWE1NmE0MjExZTk0ZThkMGRiYmM2ZjE1YTQ5OWRmODM1MzliYmUy"

    def setup
      unless blockchain.wallet.address == FOUNDER_ADDRESS
        raise "CreateTransaction(dApp) have to activate with wallet at wallets/testnet-0.json"
      end

      unless node.network_type == "testnet"
        raise "node must run on testnet for CreateTransaction(dApp)"
      end
    end

    def transaction_actions : Array(String)
      ["create_transaction_sample"]
    end

    def transaction_related?(action : String) : Bool
      action == "create_transaction_sample"
    end

    def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      raise "invalid transaction message for create_transaction_sample" unless transaction.message.includes?(":")

      target_transaction_id = transaction.message.split(":")[0]

      existing_transactions = prev_transactions
                              .select { |prev_transaction| prev_transaction.action == "create_transaction_sample" }
                              .select { |prev_transaction| prev_transaction.message.includes?(":") }
                              .select { |prev_transaction| prev_transaction.message.split(":")[0] == target_transaction_id }

      if existing_transactions.size > 0
        raise "duplicate transaction for create_transaction_sample: #{transaction.message}"
      end

      true
    end

    def record(chain : Models::Chain)
      return if chain.size < @latest_loaded_block_index

      chain[@latest_loaded_block_index..-1].each do |block|
        block.transactions.each do |transaction|

          if transaction.token == "SHARI" &&
             transaction.senders.size == 1 &&
             transaction.recipients.size == 1 &&
             transaction.senders[0][:amount] == 10 &&
             transaction.recipients[0][:amount] == 10 &&
             transaction.recipients[0][:address] == FOUNDER_ADDRESS

            create_transaction(transaction)
          end
        end
      end

      @latest_loaded_block_index = chain.size
    end

    def clear
    end

    def rpc?(call, json, context, params)
      nil
    end

    def create_transaction(transaction)
      action = "create_transaction_sample"

      senders = Models::Senders.new
      senders.push({
                     address: FOUNDER_ADDRESS,
                     public_key: blockchain.wallet.public_key,
                     amount: 5_i64,
                     fee: 1_i64,
                   })

      recipients = Models::Recipients.new
      recipients.push({
                        address: transaction.senders[0][:address],
                        amount: 5_i64,
                      })

      message = "#{transaction.id}: Thanks for sending me 10 SHARI!"
      token = BuildIn::UTXO::DEFAULT

      unsigned_transaction = blockchain.create_unsigned_transaction(
        action,
        senders,
        recipients,
        message,
        token,
      )

      secp256k1 = Core::ECDSA::Secp256k1.new
      private_key = Wif.new(blockchain.wallet.wif).private_key

      sign = secp256k1.sign(
        private_key.as_big_i,
        unsigned_transaction.to_hash,
      )

      signed_transaction = unsigned_transaction.signed(
        sign[0].to_s(base: 16),
        sign[1].to_s(base: 16),
      )

      node.broadcast_transaction(signed_transaction)

      info "create a transaction from 'CreateTransaction': #{signed_transaction.id}"
    end
  end
end
