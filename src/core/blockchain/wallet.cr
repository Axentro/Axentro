module ::Sushi::Core

  class Wallet

    JSON.mapping({
      public_key: String,
      wif: String,
      address: String,
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

      self.from_json(File.read(wallet_path))
    end

    def self.create(testnet = false)
      network = testnet ? TESTNET : MAINNET
      keys = Keys.generate(network)

      {
        public_key: keys.public_key.as_hex,
        wif: keys.wif.as_hex,
        address: keys.address.as_hex
      }
    end

    def self.verify!(public_key : String, wif : String, address : String) : Bool
      Keys.is_valid?(public_key, wif, address)
    end

    def self.address_network_type(address : String) : Models::Network
      Address.from(address).network
    end

    include Keys
    include Hashes
  end
end
