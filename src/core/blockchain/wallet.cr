module ::Sushi::Core

 class EncryptedWallet
   JSON.mapping({
     cipher: String
   })

   getter cipher : String

   def initialize(@cipher : String)
   end
 end

  class Wallet

    JSON.mapping({
      private_key: String,
      public_key: String,
      wif: String,
      address: String,
    })

    getter private_key : String
    getter public_key : String
    getter wif : String
    getter address : String

    def initialize(@private_key : String, @public_key : String, @wif : String, @address : String)
    end

    def verify!
      Wallet.verify!(@private_key, @public_key, @wif, @address)
    end

    def self.from_path(wallet_path : String) : EncryptedWallet
      raise "Failed to find wallet at #{wallet_path}, create it first!" unless File.exists?(wallet_path)

      EncryptedWallet.from_json(File.read(wallet_path))
    end

    def self.decrypt(encrypted_wallet : EncryptedWallet, password) : Wallet
      begin
        decrypted_wallet = BlowFish.decrypt(encrypted_wallet.cipher, password)
      rescue ex
        raise "Failed to decrypt wallet with supplied password"
      end

      wallet = Wallet.from_json(decrypted_wallet)
      verify!(wallet.private_key, wallet.public_key, wallet.wif, wallet.address)
      wallet
    end

    def self.create(password ,testnet = false) : EncryptedWallet

      raise "Password is too short, it must be a minimum of 16 characters" if password.size < 16

      network = testnet ? TESTNET : MAINNET
      keys = Keys.generate(network)

      wallet = {
        private_key: keys.private_key.as_hex,
        public_key: keys.public_key.as_hex,
        wif: keys.wif.as_hex,
        address: keys.address.as_hex
      }

      encrypted_wallet = BlowFish.encrypt(wallet.to_json, password)
      EncryptedWallet.new(encrypted_wallet)
    end

    def self.verify!(private_key : String, public_key : String, wif : String, address : String) : Bool
      Keys.is_valid?(private_key, public_key, wif, address)
    end

    def self.address_network_type(address : String) : Models::Network
      Address.from(address).network
    end

    include Keys
    include Hashes
  end
end
