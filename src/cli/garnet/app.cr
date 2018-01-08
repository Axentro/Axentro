module ::Garnet::Interface::Garnet
  class App < CLI

    @wallet_path : String?
    @recipient_address : String?
    @amount : Float64?
    @node : String?

    def sub_actions
      [
        {
          name: "send",
          desc: "Send garnet coins to specified address",
        },
        {
          name: "fees",
          desc: "Show fees for each action",
        },
      ]
    end

    def option_parser
      OptionParser.new do |parser|
        parser.on("-w WALLET_PATH", "--wallet-path=WALLET_PATH", "wallet json's path") { |wallet_path|
          @wallet_path = wallet_path
        }
        parser.on("-r ADDRESS", "--recipient-address=ADDRESS", "recipient's address") { |recipient_address|
          @recipient_address = recipient_address
        }
        parser.on("-a AMOUNT", "--amount=AMOUNT", "The amount") { |amount|
          @amount = amount.to_f
        }
        parser.on("-n NODE", "--node=NODE", "Connecting node") { |node|
          @node = node
        }
      end
    end

    def run_impl(action_name)
      case action_name
      when "send"
        send
      when "fees"
        fees
      end
    end

    def fees
      puts_success("Showing fees for each action.")
      puts_info("send     : #{FEE_SEND}")
      exit 0
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
