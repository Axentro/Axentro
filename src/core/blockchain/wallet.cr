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
      decrypted_wallet = BlowFish.decrypt(encrypted_wallet.cipher, password)
      # TODO - veriy wallet before returning and handle any errors from decrypt
      Wallet.from_json(decrypted_wallet)
    end

    def self.create(password ,testnet = false) : EncryptedWallet

      # raise "Password is too short, it must be a minimum of 16 characters" if password.size < 17

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

    # def self.verify!(secret_key : String,
    #                  public_key_x : String,
    #                  public_key_y : String,
    #                  address : String) : Bool
    #   secp256k1 = ECDSA::Secp256k1.new
    #   secret_key_raw = BigInt.new(Base64.decode_string(secret_key), base: 10)
    #   public_key_raw_x = BigInt.new(Base64.decode_string(public_key_x), base: 10)
    #   public_key_raw_y = BigInt.new(Base64.decode_string(public_key_y), base: 10)
    #
    #   raise "Invalid checksum for #{address}" unless valid_checksum?(address)
    #
    #   public_key = secp256k1.create_key_pair(secret_key_raw)[:public_key]
    #   public_key_x = public_key.x.to_s(base: 10)
    #   public_key_y = public_key.y.to_s(base: 10)
    #
    #   raise "Invalid public key (public_key_x) for #{public_key_raw_x} != #{public_key_x}" if public_key_raw_x.to_s != public_key_x
    #   raise "Invalid public key (public_key_y) for #{public_key_raw_y} != #{public_key_y}" if public_key_raw_y.to_s != public_key_y
    #
    #   true
    # end

    def self.address_network_type(address : String) : Models::Network
      Address.from(address).network
    end

    include Keys
    include Hashes
  end
end
