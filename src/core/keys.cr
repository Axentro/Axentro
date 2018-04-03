# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

module ::Sushi::Core::Keys
  include Sushi::Core::Models
  include Sushi::Core::Hashes

  MAINNET = {prefix: "M0", name: "mainnet"}
  TESTNET = {prefix: "T0", name: "testnet"}

  class Keys
    getter private_key : PrivateKey
    getter public_key : PublicKey
    getter wif : Wif
    getter address : Address

    def initialize(@private_key : PrivateKey, @public_key : PublicKey, @wif : Wif, @address : Address)
    end

    def self.generate(network : Network = MAINNET)
      secp256k1 = ECDSA::Secp256k1.new
      key_pair = secp256k1.create_key_pair
      private_key = PrivateKey.new(key_pair[:secret_key].to_s(16), network)
      public_key = PublicKey.new(key_pair[:public_key].x.to_s(16) + key_pair[:public_key].y.to_s(16), network)
      Keys.new(private_key, public_key, private_key.wif, public_key.address)
    end

    def self.is_valid?(public_key : String, wif : String, address : String)
      address = Address.from(address)
      wif = Wif.new(wif)

      raise "network mismatch between address and wif" if address.network != wif.network

      public_key = PublicKey.from(public_key, address.network)
      raise "public key mismatch between public key and wif" if public_key.as_hex != wif.public_key.as_hex

      true
    end
  end
end

require "./keys/*"
