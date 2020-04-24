# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

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
    # It's "SUSHI"
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
    #    transaction.token == "SUSHI"
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
    # For example, let me assume the dApp will send 0.00005 SUSHI back to the senders if "some_action" transactions are created.
    # ```
    # block.transactions.each do |transaction|
    #   if transaction.action == "some_action"
    #     id = create_transaction_id(block, transaction)
    #     action = "send"
    #     sender = create_sender(scale_i64("0.00005"))
    #     recipient = create_recipient(transaction.recipients[0][:address], scale_i64("0.00005"))
    #     message = "I'll back you 0.00005 SUSHI"
    #     token = TOKEN_DEFAULT
    #
    #     create_transaction(id, action, sender, recipient, message, token)
    #   end
    # end
    # ```
    #
    # (You can see the details of `create_sender`, `create_recipient` and `create_transaction` below.)
    #
    abstract def new_block(block : SlowBlock | FastBlock)

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
    # You can set the timing when your dApps will be activated
    # Return a block "index" (not a blockchain's size)
    # e.g. If you return 100, the dApp will be activated on block index 100, 101, ...
    # If you return nil, the dApp will be activated when you start a node with it.
    #
    abstract def activate : Int64 | Nil

    #
    # You can set the timing when your dApps will be deactivated
    # Return a block "index" (not a blockchain's size)
    # e.g. If you return 100, the dApp will be activated on block index ..., 98, 99.
    # If you return nil, the dApp will never be deactivated.
    #
    abstract def deactivate : Int64 | Nil

    #
    # This is a wrapper method that you can create a sender
    # Note that creating transactions on dApps on SushiChain is restricted.
    # The sender must be the node launcher which the dApps be activated on.
    # So, in this method, you only have to specify the sending amount of the token.
    # Also the fee is fixed as 0.0001 SUSHI.
    #
    def create_sender(amount : String) : SendersDecimal
      senders = SendersDecimal.new
      senders.push({
        address:    blockchain.wallet.address,
        public_key: blockchain.wallet.public_key,
        amount:     amount,
        fee:        "0.0001",
        signature:  "0",
      })
      senders
    end

    #
    # This is a wrapper method that you can create a recipient.
    # You can specify a recipient's public address and amount of the token.
    #
    def create_recipient(address : String, amount : String) : RecipientsDecimal
      recipients = RecipientsDecimal.new
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
    # You can create the id by `create_transaction_id` to be uniq for each block and transaction.
    # If you create it manually (it's not recommended), `sha256` is useful for creating the id.
    #
    def create_transaction(
      id : String,
      action : String,
      senders : SendersDecimal,
      recipients : RecipientsDecimal,
      message : String,
      token : String,
      kind : TransactionKind
    ) : Bool
      if blockchain.indices.get(id)
        info "skip creating transaction #{id}"
        return false
      end

      unsigned_transaction = blockchain.transaction_creator.create_unsigned_transaction_impl(
        action,
        senders,
        recipients,
        message,
        token,
        kind,
        id,
      )

      signed_transaction = unsigned_transaction.as_signed([blockchain.wallet])

      node.broadcast_transaction(signed_transaction)

      true
    end

    #
    # Create a transaction id to be uniq for each block and transaction.
    # As you can see, the `valid_addresses`, `valid_networks` and related_transaction_actions`
    # are used to create it.
    # So if you will change it, the id also be changed.
    #
    def create_transaction_id(block : SlowBlock | FastBlock, transaction : Transaction) : String
      sha256(
        valid_addresses.join("") +
        valid_networks.join("") +
        related_transaction_actions.join("") +
        block.to_hash +
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

    def record(chain : Blockchain::Chain)
      # TODO - replace this with fetch from db
      return if chain.size < @latest_loaded_block_index

      chain[@latest_loaded_block_index..-1].each do |block|
        next if !activate.nil? && block.index < activate.not_nil!
        next if !deactivate.nil? && block.index >= deactivate.not_nil!

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

    def on_message(action : String, from_address : String, content : String, from = nil)
      false
    end

    include TransactionModels
  end
end

require "./*"
