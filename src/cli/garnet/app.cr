module ::Garnet::Interface::Garnet
  class App < CLI

    @recipient_address : String?
    @wallet_path       : String?
    @address           : String?
    @amount            : Float64?
    @node              : String?
    @header            : Bool = false
    @index             : Int32?
    @transaction_id    : String?
    @unconfirmed       : Bool = false

    def sub_actions
      [
        {
          name: "amount",
          desc: "Show remaining amount of Garnet token for specified address",
        },
        {
          name: "send",
          desc: "Send garnet coins to a specified address",
        },
        {
          name: "fees",
          desc: "Show fees for each action",
        },
        {
          name: "size",
          desc: "Show current blockchain size",
        },
        {
          name: "blockchain",
          desc: "Get whole blockchain. Headers (without transactions) only with --header option",
        },
        {
          name: "block",
          desc: "Get a block for a specified index or transaction id",
        },
        {
          name: "transactions",
          desc: "Get trasactions in a specified block",
        },
        {
          name: "transaction",
          desc: "Get a transaction for a transaction id",
        },
      ]
    end

    def option_parser
      OptionParser.new do |parser|
        parser.on(
          "-w WALLET_PATH",
          "--wallet-path=WALLET_PATH",
          "wallet json's path"
        ) { |wallet_path|
          @wallet_path = wallet_path
        }
        parser.on("-a ADDRESS", "--address=ADDRESS", "Public address") { |address|
          @address = address
        }
        parser.on(
          "-r ADDRESS",
          "--recipient-address=ADDRESS",
          "recipient's address"
        ) { |recipient_address|
          @recipient_address = recipient_address
        }
        parser.on("-a AMOUNT", "--amount=AMOUNT", "The amount of Garnet token") { |amount|
          @amount = amount.to_f
        }
        parser.on("-n NODE", "--node=NODE", "Connecting node") { |node|
          @node = node
        }
        parser.on("-h", "--header", "Get headers only when get a blockchain") { @header = true }
        parser.on("-i INDEX", "--index=INDEX", "Block index") { |index| @index = index.to_i }
        parser.on(
          "-t TRANSACTION_ID",
          "--transaction_id=TRANSACTION_ID",
          "Transaction id"
        ) { |transaction_id|
          @transaction_id = transaction_id
        }
        parser.on("-u", "--unconfirmed", "Showing UNCONFIRMED amounts") {
          @unconfirmed = true
        }
      end
    end

    def run_impl(action_name)
      case action_name
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
      if @wallet_path.nil? && @address.nil?
        puts_help("Please specify a wallet path or an address")
      end

      unless node = @node
        puts_help("Please specify a connecting node")
      end

      address = if wallet_path = @wallet_path
                  wallet = Core::Wallet.from_path(wallet_path)
                  wallet.address
                elsif _address = @address
                  _address
                else
                  puts_help("Please specify a wallet path or an address")
                end

      payload = { call: "amount", address: address, unconfirmed: @unconfirmed }.to_json

      body = rpc(node, payload)

      puts_success("Show Garnet token amount of #{address}")
      puts_info(body)
    end

    def send
      unless wallet_path = @wallet_path
        puts_help("Please specify your wallet")
      end

      unless recipient_address = @recipient_address
        puts_help("Please specify recipient address")
      end

      unless amount = @amount
        puts_help("Please specify the amount")
      end

      unless node = @node
        puts_help("Please specify a connecting node")
      end

      unless Core::Wallet.valid_checksum?(recipient_address)
        raise "Invalid checksum for recipient address: #{recipient_address}"
      end

      wallet = Core::Wallet.from_path(wallet_path)

      senders = Core::Models::Senders.new
      senders.push(
        {
          address: wallet.address,
          px: wallet.public_key_x,
          py: wallet.public_key_y,
          amount: amount + min_fee_of_action("send"),
        }
      )

      recipients = Core::Models::Recipients.new
      recipients.push(
        {
          address: recipient_address,
          amount: amount,
        }
      )

      add_transaction(node, wallet, "send", senders, recipients, "0")
    end

    def fees
      puts_success("Showing fees for each action.")
      puts_info("send     : #{FEE_SEND}")
      exit 0
    end

    def size
      unless node = @node
        puts_help("Please specify a connecting node")
      end

      payload = { call: "blockchain_size" }.to_json

      body = rpc(node, payload)

      puts_success("Current blockchain size is #{body}")
    end

    def blockchain
      unless node = @node
        puts_help("Please specify a connecting node")
      end

      payload = { call: "blockchain", header: @header }.to_json

      body = rpc(node, payload)

      puts_success("Show current blockchain")
      puts_info(body)
    end

    def block
      unless node = @node
        puts_help("Please specify a connecting node")
      end

      if @index.nil? && @transaction_id.nil?
        puts_help("Please specify a block index or transaction id")
      end

      payload = if index = @index
                  @message = "Show a block for index: #{@index}"
                  { call: "block", index: index, header: @header }.to_json
                elsif transaction_id = @transaction_id
                  @message = "Show a block for transaction: #{@transaction_id}"
                  { call: "block", transaction_id: transaction_id, header: @header }.to_json
                else
                  puts_help("Please specify a block index or transaction id")
                end

      body = rpc(node, payload)

      puts_success(@message)
      puts_info(body)
    end

    def transactions
      unless node = @node
        puts_help("Please specify a connecting node")
      end

      unless index = @index
        puts_help("Please specify a block index")
      end

      payload = { call: "transactions", index: index }.to_json

      body = rpc(node, payload)

      puts_success("Show transactions in a block #{index}")
      puts_info(body)
    end

    def transaction
      unless node = @node
        puts_help("Please specify a connecting node")
      end

      unless transaction_id = @transaction_id
        puts_help("Please specify a transaction id")
      end

      payload = { call: "transaction", transaction_id: transaction_id }.to_json

      body = rpc(node, payload)

      puts_success("Show the transaction #{transaction_id}")
      puts_info(body)
    end

    def add_transaction(node : String,
                        wallet : Core::Wallet,
                        action : String,
                        senders : Core::Models::Senders,
                        recipients : Core::Models::Recipients,
                        content_hash : String)
      unsigned_transaction =
        create_unsigned_transaction(node, action, senders, recipients, content_hash)

      signed_transaction = sign(wallet, unsigned_transaction)

      payload = {
        call: "create_transaction",
        transaction: signed_transaction.to_json
      }.to_json

      rpc(node, payload)

      puts_success "Successfully create your transaction!"
      puts_success "=> #{signed_transaction.id}"
    end

    def create_unsigned_transaction(node : String,
                                    action : String,
                                    senders : Core::Models::Senders,
                                    recipients : Core::Models::Recipients,
                                    content_hash : String)
      payload = {
        call: "create_unsigned_transaction",
        action: action,
        senders: senders.to_json,
        recipients: recipients.to_json,
        content_hash: content_hash,
      }.to_json

      body = rpc(node, payload)

      Core::Transaction.from_json(body)
    end

    def sign(wallet : Core::Wallet, transaction : Core::Transaction) : Core::Transaction
      secp256k1 = Core::ECDSA::Secp256k1.new

      sign = secp256k1.sign(
        BigInt.new(Base64.decode_string(wallet.secret_key), base: 10),
        transaction.to_hash,
      )

      transaction.signed(
        sign[0].to_s(base: 16),
        sign[1].to_s(base: 16),
      )
    end

    include Core::Fees
  end
end
