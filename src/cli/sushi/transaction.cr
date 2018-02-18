module ::Sushi::Interface::Sushi
  class Transaction < CLI
    def sub_actions
      [
        {
          name: "send",
          desc: "send Sushi coins to a specified address",
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
        Options::ADDRESS,
        Options::AMOUNT,
        Options::MESSAGE,
        Options::BLOCK_INDEX,
        Options::TRANSACTION_ID,
      ])
    end

    def run_impl(action_name)
      case action_name
      when "send"
        send
      when "transactions"
        transactions
      when "transaction"
        transaction
      end
    end

    def send
      puts_help(HELP_CONNECTING_NODE) unless node = @connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = @wallet_path
      puts_help(HELP_ADDRESS_RECIPIENT) unless recipient_address = @address
      puts_help(HELP_AMOUNT) unless amount = @amount

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

    def transactions
      puts_help(HELP_CONNECTING_NODE) unless node = @connect_node
      puts_help(HELP_BLOCK_INDEX) unless block_index = @block_index

      payload = {call: "transactions", index: block_index}.to_json

      body = rpc(node, payload)

      # todo json
      puts_success("show transactions in a block #{block_index}")
      puts_info(body)
    end

    def transaction
      puts_help(HELP_CONNECTING_NODE) unless node = @connect_node
      puts_help(HELP_TRANSACTION_ID) unless transaction_id = @transaction_id

      payload = {call: "transaction", transaction_id: transaction_id}.to_json

      body = rpc(node, payload)

      puts_success("show the transaction #{transaction_id}")
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
        puts_success "successfully create your transaction!"
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
