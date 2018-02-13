require "../cli"

module ::Sushi::Interface::Sushi
  class Root < CLI
    @wallet_path : String?
    @address : String?
    @amount : Int64?
    @node : String?
    @header : Bool = false
    @index : Int32?
    @transaction_id : String?
    @unconfirmed : Bool = false
    @json : Bool = false
    @is_testnet : Bool = false
    @message : String = ""

    def sub_actions
      [
        {
          name: "create",
          desc: "Create a wallet file",
        },
        {
          name: "verify",
          desc: "Verify a wallet file",
        },
        {
          name: "amount",
          desc: "Show remaining amount of Sushi coins for specified address",
        },
        {
          name: "send",
          desc: "Send Sushi coins to a specified address",
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
        parser.on("-m AMOUNT", "--amount=AMOUNT", "The amount of Sushi coins") { |amount|
          @amount = amount.to_i64
        }
        parser.on("--message=MESSAGE", "Add message into transaction") { |message|
          @message = message
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
        parser.on("-u", "--unconfirmed", "Showing UNCONFIRMED amount") {
          @unconfirmed = true
        }
        parser.on("-j", "--json", "Print results as json") {
          @json = true
        }
        parser.on("--testnet", "Set network type as testnet (default is mainnet)") {
          @is_testnet = true
        }
      end
    end

    def run_impl(action_name)
      case action_name
      when "create"
        create
      when "verify"
        verify
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

    def create
      unless wallet_path = @wallet_path
        puts_help(HELP_WALLET_PATH)
      end

      wallet_path = wallet_path.ends_with?(".json") ? wallet_path : wallet_path + ".json"

      if File.exists?(wallet_path)
        puts_help(HELP_WALLET_ALREADY_EXISTS % wallet_path)
      end

      wallet_json = Core::Wallet.create(@is_testnet).to_json

      File.write(wallet_path, wallet_json)

      unless @json
        puts_success("Your new wallet has been created at #{wallet_path}")
        puts_success("Please take backup of the json file and keep it secret.")
      else
        puts wallet_json
      end
    end

    def verify
      unless wallet_path = @wallet_path
        puts_help(HELP_WALLET_PATH)
      end

      wallet = Core::Wallet.from_path(wallet_path)
      puts_success "#{wallet_path} is perfect!" if wallet.verify!

      network = Core::Wallet.address_network_type(wallet.address)
      puts_success "Network (#{network[:prefix]}): #{network[:name]}"
    end

    def amount
      if @wallet_path.nil? && @address.nil?
        puts_help(HELP_WALLET_PATH_OR_ADDRESS)
      end

      unless node = @node
        puts_help(HELP_CONNECTING_NODE)
      end

      address = if wallet_path = @wallet_path
                  wallet = Core::Wallet.from_path(wallet_path)
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
      unless wallet_path = @wallet_path
        puts_help(HELP_WALLET_PATH)
      end

      unless recipient_address = @address
        puts_help(HELP_ADDRESS_RECIPIENT)
      end

      unless amount = @amount
        puts_help(HELP_AMOUNT)
      end

      unless node = @node
        puts_help(HELP_CONNECTING_NODE)
      end

      to_address = Address.from(recipient_address, "recipient")

      wallet = Core::Wallet.from_path(wallet_path)

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
      unless node = @node
        puts_help(HELP_CONNECTING_NODE)
      end

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
      unless node = @node
        puts_help(HELP_CONNECTING_NODE)
      end

      payload = {call: "blockchain", header: @header}.to_json

      body = rpc(node, payload)

      puts_success("Show current blockchain")
      puts_info(body)
    end

    def block
      unless node = @node
        puts_help(HELP_CONNECTING_NODE)
      end

      if @index.nil? && @transaction_id.nil?
        puts_help(HELP_BLOCK_INDEX_OR_TRANSACTION_ID)
      end

      payload = if index = @index
                  success_message = "Show a block for index: #{@index}"
                  {call: "block", index: index, header: @header}.to_json
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
      unless node = @node
        puts_help(HELP_CONNECTING_NODE)
      end

      unless index = @index
        puts_help(HELP_BLOCK_INDEX)
      end

      payload = {call: "transactions", index: index}.to_json

      body = rpc(node, payload)

      puts_success("Show transactions in a block #{index}")
      puts_info(body)
    end

    def transaction
      unless node = @node
        puts_help(HELP_CONNECTING_NODE)
      end

      unless transaction_id = @transaction_id
        puts_help(HELP_TRANSACTION_ID)
      end

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
  end
end

include ::Sushi::Interface
include Sushi::Core::Keys

::Sushi::Interface::Sushi::Root.new(
  {name: "sushi", desc: "Sushi's command line client"}, [] of SushiAction
).run
