module ::Sushi::Core

  class WalletException < Exception
  end

  class EncryptedWallet
    JSON.mapping({
      source:     String,
      ciphertext: String,
      address:    String,
      salt:       String,
    })

    def self.from_path(wallet_path : String) : EncryptedWallet
      raise "Failed to find encrypted wallet at #{wallet_path}" unless File.exists?(wallet_path)
      encrypted_wallet = self.from_json(File.read(wallet_path))
      raise "This wallet was not encrypted with the sushi binary" unless encrypted_wallet.source == "sushi"
      encrypted_wallet
    rescue e : Exception
      raise "Error: #{e.message}"
    end
  end

  class Wallet
    JSON.mapping({
      public_key: String,
      wif:        String,
      address:    String,
    })

    getter public_key : String
    getter wif : String
    getter address : String

    def initialize(@public_key : String, @wif : String, @address : String)
    end

    def verify!
      Wallet.verify!(@public_key, @wif, @address)
    end

    def self.from_path(wallet_path : String) : Wallet
      raise "Failed to find wallet at #{wallet_path}, create it first!" unless File.exists?(wallet_path)
      begin
        self.from_json(File.read(wallet_path))
      rescue e
        raise WalletException.new(e.message)
      end
    end

    def self.create(testnet = false)
      network = testnet ? TESTNET : MAINNET
      keys = Keys.generate(network)

      {
        public_key: keys.public_key.as_hex,
        wif:        keys.wif.as_hex,
        address:    keys.address.as_hex,
      }
    end

    def self.verify!(public_key : String, wif : String, address : String) : Bool
      Keys.is_valid?(public_key, wif, address)
    end

    def self.address_network_type(address : String) : Models::Network
      Address.from(address).network
    end

    def self.encrypt(password : String, wallet : Wallet)
      encrypted = BlowFish.encrypt(password, wallet.to_json)
      {
        source:     "sushi",
        ciphertext: encrypted[:data],
        address:    wallet.address,
        salt:       encrypted[:salt],
      }
    rescue e
      raise "Failed to encrypt the wallet: #{e.message}"
    end

    def self.encrypt(password : String, wallet_path : String)
      begin
        wallet = self.from_path(wallet_path)
      rescue e
        raise "Failed to encrypt the wallet: #{e.message}"
      end
      self.encrypt(password, wallet)
    end

    def self.decrypt(password : String, encrypted_wallet : EncryptedWallet)
      ciphertext = encrypted_wallet.ciphertext
      salt = encrypted_wallet.salt
      BlowFish.decrypt(password, ciphertext, salt)
    rescue OpenSSL::Error
      raise "Failed to decrypt the wallet with the supplied password"
    rescue e
      raise "Failed to decrypt the wallet: #{e.message}"
    end

    def self.decrypt(password : String, wallet_path : String)
      begin
        encrypted_wallet = EncryptedWallet.from_path(wallet_path)
      rescue e
        raise "Failed to decrypt the wallet: #{e.message}"
      end
      self.decrypt(password, encrypted_wallet)
    end

    include Keys
    include Hashes
  end
end
