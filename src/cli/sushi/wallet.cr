module ::Sushi::Interface::Sushi
  class Wallet < CLI

    def sub_actions
      [
        {
          name: "create",
          desc: "create a wallet file",
        },
        {
          name: "verify",
          desc: "verify a wallet file",
        },
        {
          name: "encrypt",
          desc: "encrypt a sushi wallet",
        },
        {
          name: "decrypt",
          desc: "decrypt a sushi wallet (that was encrypted using sushi)",
        },
      ]
    end

    def option_parser
      create_option_parser([
                             Options::WALLET_PATH,
                             Options::WALLET_PASSWORD,
                             Options::IS_TESTNET,
                             Options::ENCRYPTED,
                             Options::JSON,
                           ])
    end

    def run_impl(action_name)
      case action_name
      when "create"
        create
      when "verify"
        verify
      when "encrypt"
        encrypt
      when "decrypt"
        decrypt
      end
    end

    def create
      puts_help(HELP_WALLET_PATH) unless wallet_path = @wallet_path

      wallet_path = wallet_path.ends_with?(".json") ? wallet_path : wallet_path + ".json"

      puts_help(HELP_WALLET_ALREADY_EXISTS % wallet_path) if File.exists?(wallet_path)

      wallet = Core::Wallet.from_json(Core::Wallet.create(@is_testnet).to_json)

      if @encrypted
        puts_help(HELP_WALLET_PASSWORD) unless wallet_password = (@wallet_password || ENV["WALLET_PASSWORD"]?)

        encrypted_wallet = Core::Wallet.encrypt(wallet_password, wallet)

        File.write(wallet_path, encrypted_wallet.to_json)
      else
        File.write(wallet_path, wallet.to_json)
      end

      unless @json
        puts_success("Your new wallet has been created at #{wallet_path}")
        puts_success("Please take backup of the json file and keep it secret.")
      else
        puts wallet.to_json
      end
    end

    def verify
      puts_help(HELP_WALLET_PATH) unless wallet_path = @wallet_path

      wallet = get_wallet(wallet_path, @wallet_password)

      puts_success "#{wallet_path} is perfect!" if wallet.verify!
      puts_success "Address: #{wallet.address}"

      network = Core::Wallet.address_network_type(wallet.address)
      puts_success "Network (#{network[:prefix]}): #{network[:name]}"
    end

    def encrypt
      puts_help(HELP_WALLET_PATH) unless wallet_path = @wallet_path
      puts_help(HELP_WALLET_PASSWORD) unless wallet_password = @wallet_password

      encrypted_wallet_json = Core::Wallet.encrypt(wallet_password, wallet_path).to_json
      encrypted_wallet_path = "encrypted-" + wallet_path

      puts_help(HELP_WALLET_ALREADY_EXISTS % encrypted_wallet_path) if File.exists?(encrypted_wallet_path)

      File.write(encrypted_wallet_path, encrypted_wallet_json)

      unless @json
        puts_success("Your wallet has been encrypted at #{encrypted_wallet_path}")
        puts_success("Please don't forget your password - there is no way to recover an encrypted wallet.")
      else
        puts encrypted_wallet_json
      end
    end

    def decrypt
      puts_help(HELP_WALLET_PATH) unless wallet_path = @wallet_path
      puts_help(HELP_WALLET_PASSWORD) unless wallet_password = @wallet_password

      decrypted_wallet_json = Core::Wallet.decrypt(wallet_password, wallet_path)
      decrypted_wallet_path = "decrypted-" + wallet_path

      puts_help(HELP_WALLET_ALREADY_EXISTS % decrypted_wallet_path) if File.exists?(decrypted_wallet_path)

      File.write(decrypted_wallet_path, decrypted_wallet_json)

      unless @json
        puts_success("Your wallet has been decrypted at #{decrypted_wallet_path}")
      else
        puts decrypted_wallet_json
      end
    end

    include GlobalOptionParser
  end
end
