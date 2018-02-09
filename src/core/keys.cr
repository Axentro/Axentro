module ::Sushi::Core::Keys
  include Sushi::Core::Models

  MAINNET = {prefix: "M0", name: "mainnet"}
  TESTNET = {prefix: "T0", name: "testnet"}
  
  class Keys
    getter private_key : PrivateKey
    getter public_key : PublicKey
    getter wif : Wif
    getter address : Address

    def initialize(@private_key : PrivateKey, @public_key : PublicKey, @wif : Wif, @address : Address)
    end

    def self.generate(network : Network = {prefix: "M0", name: "mainnet"})
      secp256k1 = ECDSA::Secp256k1.new
      key_pair = secp256k1.create_key_pair
      private_key = PrivateKey.new(key_pair[:secret_key].to_s(16), network)
      public_key = PublicKey.new(key_pair[:public_key].x.to_s(16) + key_pair[:public_key].y.to_s(16), network)
      Keys.new(private_key, public_key, private_key.wif, public_key.address)
    end
  end
end

require "./keys/*"
