module ::Garnet::Interface::Garnet
  class Wallet < CLI

    @wallet_path : String?
    @address : String?
    @node : String?
    @unconfirmed = false

    def sub_actions
      [
        {
          name: "create",
          desc: "Create new wallet.",
        },
        {
          name: "verify",
          desc: "Verify your wallet. Specify a path to your wallet.json.",
        },
        {
          name: "amount",
          desc: "Show remaining amount for the wallet.",
        },
      ]
    end

    def option_parser
      OptionParser.new do |parser|
        parser.on("-w WALLET_PATH", "--wallet-path=WALLET_PATH", "wallet json's path") { |wallet_path|
          @wallet_path = wallet_path
        }
        parser.on("-a ADDRESS", "--address=ADDRESS", "Public address") { |address|
          @address = address
        }
        parser.on("-n NODE", "--node=NODE", "Connecting node") { |node|
          @node = node
        }
        parser.on("-u", "--unconfirmed", "Showing UNCONFIRMED amounts") {
          @unconfirmed = true
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
      end
    end

    def create
      unless wallet_path = @wallet_path
        puts_help("Please specify a wallet path")
      end

      wallet_path = wallet_path.ends_with?(".json") ? wallet_path : wallet_path + ".json"

      if File.exists?(wallet_path)
        puts_help("#{wallet_path} already exists")
      end

      wallet_json = Core::Wallet.create.to_json

      File.write(wallet_path, wallet_json)

      puts_success("Your new wallet has been created at #{wallet_path}")
      puts_success("Please take backup of the json file and keep it secret.")

      exit 0
    end

    def verify
      unless wallet_path = @wallet_path
        puts_help("Please specify a wallet path")
      end

      wallet_path = wallet_path.ends_with?(".json") ? wallet_path : wallet_path + ".json"

      puts_info "Verifying your wallet at #{wallet_path} ..."

      verify_internal!(wallet_path)

      puts_success ""
      puts_success "Your wallet is #{light_cyan("Perfect")}!"

      exit 0
    end

    def amount
      if @wallet_path.nil? && @address.nil?
        puts_help("Please specify a wallet path or an public address")
      end

      address = if @wallet_path.nil?
                  @address.not_nil!
                else
                  Core::Wallet.from_path(@wallet_path.not_nil!).address
                end

      unless node = @node
        puts_help("Please specify a connecting node")
      end

      puts_info("Showing remaining amounts on #{address}")

      payload = {
        call: "remaining_amounts",
        address: address,
        unconfirmed: @unconfirmed,
      }.to_json

      body = rpc(node, payload)

      puts_success "Amount: #{body}"
    end

    private def verify_internal!(wallet_path : String) : Bool
      wallet = Core::Wallet.from_path(wallet_path)
      wallet.verify!
    end
  end
end
