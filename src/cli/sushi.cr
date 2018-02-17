require "../cli"
require "./sushi/*"

module ::Sushi::Interface::Sushi
  class Root < CLI
    def sub_actions
      [
        {
          name: "wallet",
          desc: "create, encrypt or decrypt your wallet",
        },
        {
          name: "amount",
          desc: "show remaining amount of Sushi coins for specified address",
        },
        {
          name: "send",
          desc: "send Sushi coins to a specified address",
        },
        {
          name: "fees",
          desc: "show fees for each action",
        },
        {
          name: "size",
          desc: "show current blockchain size",
        },
        {
          name: "blockchain",
          desc: "get whole blockchain. headers (without transactions) only with --header option",
        },
        {
          name: "block",
          desc: "get a block for a specified index or transaction id",
        },
        {
          name: "transactions",
          desc: "get trasactions in a specified block",
        },
        {
          name: "transaction",
          desc: "get a transaction for a transaction id",
        },
      ]
    end

    def option_parser
      create_option_parser([
                             Options::CONNECT_NODE,
                             Options::WALLET_PATH,
                             Options::WALLET_PASSWORD,
                             Options::JSON,
                             Options::UNCONFIRMED,
                             Options::ADDRESS,
                             Options::AMOUNT,
                             Options::MESSAGE,
                             Options::BLOCK_INDEX,
                             Options::TRANSACTION_ID,
                             Options::HEADER,
                           ])
    end

    def run_impl(action_name)
      case action_name
      when "wallet"
        Wallet.new(
          {name: "wallet", desc: "create, encrypt or decrypt your wallet"},
          next_parents,
        ).run
      when "amount"
        amount
      when "send"
        send
      when "fees"
        fees
      when "size"
        size
      when "blockchain"
        blockchain
      when "block"
        block
      when "transactions"
        transactions
      when "transaction"
        transaction
      end
    end

    def amount
      puts_help(HELP_WALLET_PATH_OR_ADDRESS) if @wallet_path.nil? && @address.nil?
      puts_help(HELP_CONNECTING_NODE) unless node = @connect_node

      address = if wallet_path = @wallet_path
                  wallet = get_wallet(wallet_path, @wallet_password)
                  wallet.address
                elsif _address = @address
                  _address
                else
                  puts_help(HELP_WALLET_PATH_OR_ADDRESS)
                end

      payload = {call: "amount", address: address, unconfirmed: @unconfirmed}.to_json

      body = rpc(node, payload)

      unless @json
        json = JSON.parse(body)
        puts_success("Show Sushi coins amount of #{address}")
        puts_info(json["amount"].to_s)
      else
        puts body
      end
    end

    def send
      puts_help(HELP_WALLET_PATH) unless wallet_path = @wallet_path
      puts_help(HELP_ADDRESS_RECIPIENT) unless recipient_address = @address
      puts_help(HELP_AMOUNT) unless amount = @amount
      puts_help(HELP_CONNECTING_NODE) unless node = @connect_node

      to_address = Address.from(recipient_address, "recipient")

      wallet = get_wallet(wallet_path, @wallet_password)

      senders = Core::Models::Senders.new
      senders.push(
        {
          address:    wallet.address,
          public_key: wallet.public_key,
          amount:     amount + min_fee_of_action("send"),
        }
      )

      recipients = Core::Models::Recipients.new
      recipients.push(
        {
          address: to_address.as_hex,
          amount:  amount,
        }
      )

      add_transaction(node, wallet, "send", senders, recipients, @message)
    end

    def fees
      unless @json
        puts_success("Showing fees for each action.")
        puts_info("send     : #{FEE_SEND}")
      else
        json = {send: FEE_SEND}.to_json
        puts json
      end
    end

    def size
      puts_help(HELP_CONNECTING_NODE) unless node = @connect_node

      payload = {call: "blockchain_size"}.to_json

      body = rpc(node, payload)

      unless @json
        json = JSON.parse(body)
        puts_success("Current blockchain size is #{json["size"]}")
      else
        puts body
      end
    end

    def blockchain
      puts_help(HELP_CONNECTING_NODE) unless node = @connect_node

      payload = {call: "blockchain", header: @header}.to_json

      body = rpc(node, payload)

      puts_success("Show current blockchain")
      puts_info(body)
    end

    def block
      puts_help(HELP_CONNECTING_NODE) unless node = @connect_node
      puts_help(HELP_BLOCK_INDEX_OR_TRANSACTION_ID) if @block_index.nil? && @transaction_id.nil?

      payload = if block_index = @block_index
                  success_message = "Show a block for index: #{@block_index}"
                  {call: "block", index: block_index, header: @header}.to_json
                elsif transaction_id = @transaction_id
                  success_message = "Show a block for transaction: #{@transaction_id}"
                  {call: "block", transaction_id: transaction_id, header: @header}.to_json
                else
                  puts_help(HELP_BLOCK_INDEX_OR_TRANSACTION_ID)
                end

      body = rpc(node, payload)

      puts_success(success_message)
      puts_info(body)
    end

    def transactions
      puts_help(HELP_CONNECTING_NODE) unless node = @connect_node
      puts_help(HELP_BLOCK_INDEX) unless block_index = @block_index

      payload = {call: "transactions", index: block_index}.to_json

      body = rpc(node, payload)

      # todo json
      puts_success("Show transactions in a block #{block_index}")
      puts_info(body)
    end

    def transaction
      puts_help(HELP_CONNECTING_NODE) unless node = @connect_node
      puts_help(HELP_TRANSACTION_ID) unless transaction_id = @transaction_id

      payload = {call: "transaction", transaction_id: transaction_id}.to_json

      body = rpc(node, payload)

      puts_success("Show the transaction #{transaction_id}")
      puts_info(body)
    end

    def add_transaction(node : String,
                        wallet : Core::Wallet,
                        action : String,
                        senders : Core::Models::Senders,
                        recipients : Core::Models::Recipients,
                        message : String)
      unsigned_transaction =
        create_unsigned_transaction(node, action, senders, recipients, message)

      signed_transaction = sign(wallet, unsigned_transaction)

      payload = {
        call:        "create_transaction",
        transaction: signed_transaction.to_json,
      }.to_json

      rpc(node, payload)

      unless @json
        puts_success "Successfully create your transaction!"
        puts_success "=> #{signed_transaction.id}"
      else
        puts signed_transaction.to_json
      end
    end

    def create_unsigned_transaction(node : String,
                                    action : String,
                                    senders : Core::Models::Senders,
                                    recipients : Core::Models::Recipients,
                                    message : String)
      payload = {
        call:       "create_unsigned_transaction",
        action:     action,
        senders:    senders.to_json,
        recipients: recipients.to_json,
        message:    message,
      }.to_json

      body = rpc(node, payload)

      Core::Transaction.from_json(body)
    end

    def sign(wallet : Core::Wallet, transaction : Core::Transaction) : Core::Transaction
      secp256k1 = Core::ECDSA::Secp256k1.new

      private_key = Wif.new(wallet.wif).private_key

      sign = secp256k1.sign(
        private_key.as_big_i,
        transaction.to_hash,
      )

      transaction.signed(
        sign[0].to_s(base: 16),
        sign[1].to_s(base: 16),
      )
    end

    include Core::Fees
    include GlobalOptionParser
  end
end

include ::Sushi::Interface
include Sushi::Core::Keys

::Sushi::Interface::Sushi::Root.new(
  {name: "sushi", desc: "Sushi's command line client"}, [] of SushiAction
).run
