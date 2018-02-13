module ::Sushi::Core

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

    def self.from_path(wallet_path : String) : Wallet
      raise "Failed to find wallet at #{wallet_path}, create it first!" unless File.exists?(wallet_path)

      self.from_json(File.read(wallet_path))
    end

    def self.create(testnet = false)
      network = testnet ? TESTNET : MAINNET
      keys = Keys.generate(network)

      {
        private_key: keys.private_key.as_hex,
        public_key: keys.public_key.as_hex,
        wif: keys.wif.as_hex,
        address: keys.address.as_hex
      }
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
