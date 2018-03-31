module ::Sushi::Core::DApps::User
  #
  # This is a super class of every user defined dApps.
  #
  # You can access blockchain by `blockchain` and node by `node` from your dApp.
  # But if you change the data on it manually, your node will be rejected from other nodes.
  # So basically they are read-only.
  #
  # When you create a dApp, you have to override 6 functions.
  # You can read the details of each function below.
  #
  # **********************************************************************
  # Note that you have to modify a dapps.cr as well to activate your dApps
  # **********************************************************************
  #
  abstract class UserDApp < DApp
    #
    # It's "SHARI"
    #
    TOKEN_DEFAULT = BuildIn::UTXO::DEFAULT

    #
    # This method is required when you want to create transactions in your dApps.
    # As a restriction of dApps on SushiChain, you have to host a node to create transactions in your dApps.
    #
    # Hard code valid addresses and return it as a array of strings.
    # ```
    # ["VDAxMjJmMTcyNWE1NmE0MjExZTk0ZThkMGRiYmM2ZjE1YTQ5OWRmODM1MzliYmUy"]
    # ```
    #
    # If you don't have to create transactions, you can simply return the empty array.
    # ```
    # [] of String
    # ```
    #
    abstract def valid_addresses : Array(String)

    #
    # You can define the network types which your dApps will be activated on.
    # Currently there are "testnet" and "mainnet" on SushiChain.
    #
    # If you just want to activate it only on "testnet", return this.
    # ```
    # ["testnet"]
    # ```
    #
    # If you want to activate on both of the networks, return this.
    # ```
    # ["testnet", "mainnet"]
    # ```
    #
    abstract def valid_networks : Array(String)

    #
    # Every transactions have "action" field to determine "which transaction is related to which dApps?".
    # At here, define transaction actions as an array of strings which your dApps related to.
    #
    # For example, if your dApp related to the transactions which have "some_action" action, return this.
    # ```
    # ["some_action"]
    # ```
    #
    # If you don't have to validate any transcations, you can return an empty array of strings.
    # ```
    # [] of String
    # ```
    #
    abstract def related_transaction_actions : Array(String)

    #
    # You can check the related transaction is valid or not for your dApps.
    # The transactions coming to here is selected by `#related_transaction_actions`.
    # The prev_transactions are transactions which is in the same block.
    # If the transaction is invalid, the transaction will be rejected from the block.
    #
    # Return `true` if the transaction is valid.
    # Otherwise raise some exception with error message. (Instread of returning `false`)
    #
    # For example, let me check a number of transaction's senders and recipients here.
    # Also check the name and amount of the token.
    # ```
    # if transaction.senders.size == 1 &&
    #    transaction.recipients.size == 1 &&
    #    transaction.senders[0][:amount] == 10 &&
    #    transaction.token == "SHARI"
    #   return true
    # end
    #
    # raise "invalid transaction for my awesome dapps: #{transaction}"
    # ```
    #
    abstract def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool

    #
    # This function is called when new block is mined and broadcasted.
    # You can access the transactions in the block by `block.transactions`
    # Note that transactions which are not related to your dApps are also included in `block.transactions`.
    #
    # For example, let me assume the dApp will send 5 SHARI back to the senders if "some_action" transactions are created.
    # ```
    # block.transactions.each do |transaction|
    #   if transaction.action == "some_action"
    #     id = sha256(transaction.to_hash)
    #     action = "send"
    #     sender = create_sender(5_i64)
    #     recipient = create_recipient(transaction.recipients[0][:address], 5_i64)
    #     message = "I'll back you 5 SHARI"
    #     token = TOKEN_DEFAULT
    #
    #     create_transaction(id, action, sender, recipient, message, token)
    #   end
    # end
    # ```
    #
    # (You can see the details of `create_sender`, `create_recipient` and `create_transaction` below.)
    #
    abstract def new_block(block : Block)

    #
    # You can define a RPC (Remote Procedure Call) to your node
    # `call` is a common field that deternmine which method should be called.
    #
    # For example, define a call "hello" that return a "Hello World!"
    # ```
    # if call == "hello"
    #   context.response.print "Hello World!"
    #   return context
    # end
    # ```
    #
    abstract def define_rpc?(call : String, json : JSON::Any, context : HTTP::Server::Context) : HTTP::Server::Context?

    #
    # This is a wrapper method that you can create a sender
    # Note that creating transactions on dApps on SushiChain is restricted.
    # The sender must be the node launcher which the dApps be activated on.
    # So, in this method, you only have to specify the sending amount of the token.
    # Also the fee is fixed as 1 SHARI.
    #
    def create_sender(amount : Int64) : Models::Senders
      senders = Models::Senders.new
      senders.push({
        address:    blockchain.wallet.address,
        public_key: blockchain.wallet.public_key,
        amount:     amount,
        fee:        1_i64,
      })
      senders
    end

    #
    # This is a wrapper method that you can create a recipient.
    # You can specify a recipient's public address and amount of the token.
    #
    def create_recipient(address : String, amount : Int64) : Models::Recipients
      recipients = Models::Recipients.new
      recipients.push({
        address: address,
        amount:  amount,
      })
      recipients
    end

    #
    # This is a wrapper method that you can create transactions.
    # The process of signing to the transaction is in it.
    # You can create a `senders` and `recipients` by `create_sender` and `create_recipient`
    #
    # The id is important field that guarantee that the action will be executed only once for uniq id,
    # even if you create multiple transactions from multiple nodes.
    # `sha256` is useful for creating the id.
    #
    def create_transaction(
      id : String,
      action : String,
      senders : Models::Senders,
      recipients : Models::Recipients,
      message : String,
      token : String
    ) : Bool
      if blockchain.indices.get(id)
        info "skip creating transaction #{id}"
        return false
      end

      unsigned_transaction = blockchain.create_unsigned_transaction(
        action,
        senders,
        recipients,
        message,
        token,
        id,
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

      true
    end

    def create_id_for_transaction(transaction : Transaction) : String
      sha256(
        valid_addresses.join("") +
        valid_networks.join("") +
        related_transaction_actions.join("") +
        transaction.to_hash
      )
    end

    #
    # !!!!!!!!!!!!!!!!!!!!!!!!!
    # Do not modify below codes
    # !!!!!!!!!!!!!!!!!!!!!!!!!
    #
    def setup
      if !valid_addresses.empty? && !valid_addresses.includes?(blockchain.wallet.address)
        raise "#{self.class} cannot activate with #{blockchain.wallet.address}. available: #{valid_addresses}"
      end

      unless valid_networks.includes?(node.network_type)
        raise "node must run on #{valid_networks} for #{self.class}"
      end
    end

    def transaction_actions : Array(String)
      related_transaction_actions
    end

    def transaction_related?(action : String) : Bool
      related_transaction_actions.includes?(action)
    end

    @latest_loaded_block_index = 0

    def record(chain : Models::Chain)
      return if chain.size < @latest_loaded_block_index

      chain[@latest_loaded_block_index..-1].each do |block|
        new_block(block)
      end

      @latest_loaded_block_index = chain.size
    end

    def clear
      @latest_loaded_block_index = 0
    end

    def define_rpc?(call : String, json : JSON::Any, context : HTTP::Server::Context, params : Hash(String, String)) : HTTP::Server::Context?
      define_rpc?(call, json, context)
    end
  end
end

require "./*"
