# Copyright © 2017-2018 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

module ::Axentro::Core
  class WalletException < Exception
  end

  class EncryptedWallet
    include JSON::Serializable
    property source : String
    property ciphertext : String
    property address : String
    property salt : String

    def self.from_path(wallet_path : String) : EncryptedWallet
      raise "failed to find encrypted wallet at #{wallet_path}" unless File.exists?(wallet_path)
      encrypted_wallet = self.from_json(File.read(wallet_path))
      raise "this wallet was not encrypted with the Axentro binary" unless encrypted_wallet.source == "axentro"
      encrypted_wallet
    rescue e : Exception
      raise "#{e.message}"
    end
  end

  class Wallet
    include JSON::Serializable
    getter public_key : String
    getter wif : String
    getter address : String

    def initialize(@public_key : String, @wif : String, @address : String)
    end

    def verify!
      Wallet.verify!(@public_key, @wif, @address)
    end

    def self.from_path(wallet_path : String) : Wallet
      raise "failed to find wallet at #{wallet_path}, create it first!" unless File.exists?(wallet_path)
      begin
        self.from_json(File.read(wallet_path))
      rescue e
        raise WalletException.new(e.message)
      end
    end

    def self.create(testnet = false)
      network = testnet ? TESTNET : MAINNET
      keys = KeyRing.generate(network)

      {
        public_key: keys.public_key.as_hex,
        wif:        keys.wif.as_hex,
        address:    keys.address.as_hex,
      }
    end

    def self.create_hd(seed = nil, derivation = nil, testnet = false)
      network = testnet ? TESTNET : MAINNET
      keys = KeyRing.generate_hd(seed, derivation, network)
      seed = keys.seed
      {wallet: {
        public_key: keys.public_key.as_hex,
        wif:        keys.wif.as_hex,
        address:    keys.address.as_hex,
      }, seed: seed}
    end

    def self.verify!(public_key : String, wif : String, address : String) : Bool
      KeyRing.is_valid?(public_key, wif, address)
    end

    def self.address_network_type(address : String) : Core::Node::Network
      Address.from(address).network
    end

    def self.encrypt(password : String, wallet : Wallet)
      encrypted = BlowFish.encrypt(password, wallet.to_json)
      {
        source:     "axentro",
        ciphertext: encrypted[:data],
        address:    wallet.address,
        salt:       encrypted[:salt],
      }
    rescue e
      raise "failed to encrypt the wallet: #{e.message}"
    end

    def self.encrypt(password : String, wallet_path : String)
      begin
        wallet : Wallet = self.from_path(wallet_path)
      rescue e
        raise "failed to encrypt the wallet: #{e.message}"
      end
      self.encrypt(password, wallet)
    end

    def self.decrypt(password : String, encrypted_wallet : EncryptedWallet)
      ciphertext = encrypted_wallet.ciphertext
      salt = encrypted_wallet.salt
      BlowFish.decrypt(password, ciphertext, salt)
    rescue OpenSSL::Error
      raise "failed to decrypt the wallet with the supplied password"
    rescue e
      raise "failed to decrypt the wallet: #{e.message}"
    end

    def self.decrypt(password : String, wallet_path : String)
      begin
        encrypted_wallet = EncryptedWallet.from_path(wallet_path)
      rescue e
        raise "failed to decrypt the wallet: #{e.message}"
      end
      self.decrypt(password, encrypted_wallet)
    end

    include Keys
    include Hashes
  end
end
