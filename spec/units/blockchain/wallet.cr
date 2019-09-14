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

require "./../../spec_helper"
require "./../utils"

include Sushi::Core
include Sushi::Core::Keys
include Hashes

describe Wallet do
  describe "create new wallet" do
    it "should create a new wallet on the testnet" do
      wallet = Wallet.from_json(Wallet.create(true).to_json)
      Wallet.verify!(wallet.public_key, wallet.wif, wallet.address).should be_true
      Wallet.address_network_type(wallet.address).should eq(TESTNET)
    end

    it "should create a new wallet on the mainnet" do
      wallet = Wallet.from_json(Wallet.create(false).to_json)
      Wallet.verify!(wallet.public_key, wallet.wif, wallet.address).should be_true
      Wallet.address_network_type(wallet.address).should eq(MAINNET)
    end
  end

  describe "verify wallet" do
    it "should verify a valid wallet" do
      wallet = Wallet.from_json(Wallet.create(false).to_json)
      Wallet.verify!(wallet.public_key, wallet.wif, wallet.address).should be_true
    end

    it "should verify a valid wallet using the instance method verify!" do
      wallet = Wallet.from_json(Wallet.create(false).to_json)
      wallet.verify!.should be_true
    end
  end

  describe "#address_network_type?" do
    it "should return testnet with a valid testnet address" do
      wallet = Wallet.from_json(Wallet.create(true).to_json)
      Wallet.address_network_type(wallet.address).should eq(TESTNET)
    end

    it "should return mainnet with a valid mainnet address" do
      wallet = Wallet.from_json(Wallet.create(false).to_json)
      Wallet.address_network_type(wallet.address).should eq(MAINNET)
    end

    it "should raise an invalid network error when address not mainnet or testnet" do
      expect_raises(Exception, /invalid network: U0/) do
        Wallet.address_network_type(create_unknown_network_address)
      end
    end
  end

  describe "#from_path" do
    it "should find a wallet from the supplied path" do
      test_wallet_0 = "#{__DIR__}/../../../wallets/testnet-0.json"
      wallet = Wallet.from_path(test_wallet_0)
      Wallet.verify!(wallet.public_key, wallet.wif, wallet.address).should be_true
    end

    it "should raise a wallet not found error when no wallet file exists at the specific path" do
      expect_raises(Exception, "failed to find wallet at invalid-path, create it first!") do
        Wallet.from_path("invalid-path")
      end
    end
  end

  describe "encryption" do
    describe "#encrypt" do
      it "should encrypt a wallet" do
        wallet = "#{__DIR__}/../../utils/data/wallet1.json"
        encrypted_wallet = EncryptedWallet.from_json(Wallet.encrypt("password", wallet).to_json)
        encrypted_wallet.source.should eq("sushi")
        encrypted_wallet.ciphertext.nil?.should be_false
        encrypted_wallet.salt.nil?.should be_false
        encrypted_wallet.address.should eq(Wallet.from_json(File.read(wallet)).address)
      end

      it "should raise an error if cannot encrypt" do
        expect_raises(Exception, "failed to encrypt the wallet: failed to find wallet at invalid-wallet, create it first!") do
          EncryptedWallet.from_json(Wallet.encrypt("password", "invalid-wallet").to_json)
        end
      end
    end

    describe "#decrypt" do
      it "should decrypt a wallet" do
        wallet = "#{__DIR__}/../../utils/data/encrypted-wallet1.json"
        decrypted_wallet = Wallet.from_json(Wallet.decrypt("password", wallet))
        expected_wallet = Wallet.from_json(File.read("#{__DIR__}/../../utils/data/wallet1.json"))
        decrypted_wallet.public_key.should eq(expected_wallet.public_key)
        decrypted_wallet.wif.should eq(expected_wallet.wif)
        decrypted_wallet.address.should eq(expected_wallet.address)
      end

      it "should raise an error when wallet not found" do
        expect_raises(Exception, "failed to decrypt the wallet: failed to find encrypted wallet at invalid-wallet") do
          Wallet.from_json(Wallet.decrypt("password", "invalid-wallet"))
        end
      end

      it "should raise an error if the encrypted wallet source is not 'sushi'" do
        expect_raises(Exception, "this wallet was not encrypted with the sushi binary") do
          Wallet.from_json(Wallet.decrypt("password", "#{__DIR__}/../../utils/data/encrypted-wallet2.json"))
        end
      end

      it "should raise an error if it cannot decrypt" do
        expect_raises(Exception, "failed to decrypt the wallet with the supplied password") do
          Wallet.from_json(Wallet.decrypt("oops", "#{__DIR__}/../../utils/data/encrypted-wallet1.json"))
        end
      end
    end
  end

  STDERR.puts "< Wallet"
end

def create_unknown_network_address
  public_key = ECCrypto.create_key_pair[:hex_public_key]
  prefix = "U0"
  hashed_address = ripemd160(sha256(public_key))
  version_address = prefix + hashed_address
  hashed_address_again = sha256(sha256(version_address))
  checksum = hashed_address_again[0..5]
  Base64.strict_encode(version_address + checksum)
end
