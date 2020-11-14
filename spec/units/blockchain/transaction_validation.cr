# Copyright © 2017-2020 The Axentro Core developers
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

require "./../../spec_helper"
require "benchmark"

include Axentro::Core
include Hashes
include Units::Utils
include Axentro::Core::DApps::BuildIn
include Axentro::Core::Controllers
include Axentro::Core::Block

describe Validation::Transaction do
  describe "#validate_embedded" do
    it "should return passed when valid" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block
        coinbase_transaction = transaction_factory.make_coinbase
        transaction = transaction_factory.make_send(2000_i64)
        transaction.prev_hash = coinbase_transaction.to_hash
        transactions = [coinbase_transaction, transaction]

        result = Validation::Transaction.validate_embedded(transactions, block_factory.blockchain)
        result.passed.should eq(transactions)
        result.failed.size.should eq(0)
      end
    end

    it "should raise amount mismatch for senders and recipients if they are not equal" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block

        sender_wallet = transaction_factory.sender_wallet
        recipient_wallet = transaction_factory.recipient_wallet

        transaction_id = Transaction.create_id
        unsigned_transaction = Transaction.new(
          transaction_id,
          "send", # action
          [a_sender(sender_wallet, 40000_i64)],
          [a_recipient(recipient_wallet, 10000_i64)],
          "0",           # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW,
          TransactionVersion::V1
        )
        coinbase_transaction = transaction_factory.make_coinbase
        transaction = unsigned_transaction.as_signed([sender_wallet])
        transaction.prev_hash = coinbase_transaction.to_hash
        transactions = [coinbase_transaction, transaction]

        result = Validation::Transaction.validate_embedded(transactions, block_factory.blockchain)
        result.passed.should eq([coinbase_transaction])
        result.failed.size.should eq(1)
        result.failed.first.reason.should eq("amount mismatch for senders (0.0004) and recipients (0.0001)")
      end
    end

    it "should raise invalid prev hash if prev hash is invalid" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block
        coinbase_transaction = transaction_factory.make_coinbase
        transaction = transaction_factory.make_send(2000_i64)
        transaction.prev_hash = "invalid"
        transactions = [coinbase_transaction, transaction]

        result = Validation::Transaction.validate_embedded(transactions, block_factory.blockchain)
        result.passed.should eq([coinbase_transaction])
        result.failed.size.should eq(1)
        result.failed.first.reason.should match(/invalid prev_hash/)
      end
    end
  end

  describe "#valid_as_coinbase?" do
    it "should return passed when valid" do
      with_factory do |block_factory, transaction_factory|
        coinbase_transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Transaction::Sender,
          [a_recipient(transaction_factory.recipient_wallet, 1199999373_i64)],
          "0",           # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW,
          TransactionVersion::V1
        )

        transactions = [coinbase_transaction]
        block_index = 2_i64

        result = Validation::Transaction.validate_coinbase(transactions, [] of Transaction, block_factory.blockchain, block_index)
        result.passed.should eq([coinbase_transaction])
        result.failed.size.should eq(0)
      end
    end

    it "should raise action error if not set to 'head'" do
      with_factory do |block_factory, transaction_factory|
        coinbase_transaction = Transaction.new(
          Transaction.create_id,
          "invalid", # action
          [] of Transaction::Sender,
          [a_recipient(transaction_factory.recipient_wallet, 1199999373_i64)],
          "0",           # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW,
          TransactionVersion::V1
        )

        transactions = [coinbase_transaction]
        block_index = 2_i64

        result = Validation::Transaction.validate_coinbase(transactions, [] of Transaction, block_factory.blockchain, block_index)
        result.passed.size.should eq(0)
        result.failed.size.should eq(1)
        result.failed.first.reason.should eq("actions has to be 'head' for coinbase transaction")
      end
    end

    it "should raise message error if not set to '0'" do
      with_factory do |block_factory, transaction_factory|
        coinbase_transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Transaction::Sender,
          [a_recipient(transaction_factory.recipient_wallet, 1199999373_i64)],
          "invalid",     # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW,
          TransactionVersion::V1
        )

        transactions = [coinbase_transaction]
        block_index = 2_i64

        result = Validation::Transaction.validate_coinbase(transactions, [] of Transaction, block_factory.blockchain, block_index)
        result.passed.size.should eq(0)
        result.failed.size.should eq(1)
        result.failed.first.reason.should eq("message has to be '0' for coinbase transaction")
      end
    end

    it "should raise token error if not set to AXNT" do
      with_factory do |block_factory, transaction_factory|
        coinbase_transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Transaction::Sender,
          [a_recipient(transaction_factory.recipient_wallet, 1199999373_i64)],
          "0",       # message
          "INVALID", # token
          "0",       # prev_hash
          0_i64,     # timestamp
          1,         # scaled
          TransactionKind::SLOW,
          TransactionVersion::V1
        )

        transactions = [coinbase_transaction]
        block_index = 2_i64

        result = Validation::Transaction.validate_coinbase(transactions, [] of Transaction, block_factory.blockchain, block_index)
        result.passed.size.should eq(0)
        result.failed.size.should eq(1)
        result.failed.first.reason.should eq("token has to be AXNT for coinbase transaction")
      end
    end

    it "should raise sender error if a sender is provided" do
      with_factory do |block_factory, transaction_factory|
        coinbase_transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [a_sender(transaction_factory.sender_wallet, 40000_i64)],
          [a_recipient(transaction_factory.recipient_wallet, 1199999373_i64)],
          "0",           # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW,
          TransactionVersion::V1
        )

        transactions = [coinbase_transaction]
        block_index = 2_i64

        result = Validation::Transaction.validate_coinbase(transactions, [] of Transaction, block_factory.blockchain, block_index)
        result.passed.size.should eq(0)
        result.failed.size.should eq(1)
        result.failed.first.reason.should eq("there should be no Sender for a coinbase transaction")
      end
    end

    it "should raise prev hash error if not set to '0'" do
      with_factory do |block_factory, transaction_factory|
        coinbase_transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Transaction::Sender,
          [a_recipient(transaction_factory.recipient_wallet, 1199999373_i64)],
          "0",           # message
          TOKEN_DEFAULT, # token
          "1",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW,
          TransactionVersion::V1
        )

        transactions = [coinbase_transaction]
        block_index = 2_i64

        result = Validation::Transaction.validate_coinbase(transactions, [] of Transaction, block_factory.blockchain, block_index)
        result.passed.size.should eq(0)
        result.failed.size.should eq(1)
        result.failed.first.reason.should eq("prev_hash of coinbase transaction has to be '0'")
      end
    end

    describe "should raise invalid served amount if the served amount does not equal the served sum" do
      it "when slow coinbase" do
        with_factory do |block_factory, transaction_factory|
          coinbase_transaction = Transaction.new(
            Transaction.create_id,
            "head", # action
            [] of Transaction::Sender,
            [a_recipient(transaction_factory.recipient_wallet, 1000_i64)],
            "0",           # message
            TOKEN_DEFAULT, # token
            "0",           # prev_hash
            0_i64,         # timestamp
            1,             # scaled
            TransactionKind::SLOW,
            TransactionVersion::V1
          )

          transactions = [coinbase_transaction]
          block_index = 2_i64

          # embedded transactions are not used for this validation for slow blocks.
          result = Validation::Transaction.validate_coinbase(transactions, [] of Transaction, block_factory.blockchain, block_index)
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("invalid served amount for coinbase transaction at index: 2 expected 11.99999373 but got 0.00001")
        end
      end

      it "when fast coinbase" do
        with_factory do |block_factory, transaction_factory|
          coinbase_transaction = Transaction.new(
            Transaction.create_id,
            "head", # action
            [] of Transaction::Sender,
            [a_recipient(transaction_factory.recipient_wallet, 100000000_i64)],
            "0",           # message
            TOKEN_DEFAULT, # token
            "0",           # prev_hash
            0_i64,         # timestamp
            1,             # scaled
            TransactionKind::FAST,
            TransactionVersion::V1
          )

          transactions = [coinbase_transaction]
          block_index = 1_i64
          embedded_transactions = [transaction_factory.make_fast_send(2000)]

          result = Validation::Transaction.validate_coinbase(transactions, embedded_transactions, block_factory.blockchain, block_index)
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("invalid served amount for coinbase transaction at index: 1 expected 0.0001 but got 1")
        end
      end
    end
  end

  describe "#validate_common?" do
    it "should return passed when valid" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block

        transactions = [transaction_factory.make_send(2000_i64)]
        result = Validation::Transaction.validate_common(transactions, "testnet")
        result.passed.should eq(transactions)
        result.failed.should be_empty
      end
    end

    it "should raise transaction id length error if not 64" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block

        transaction = transaction_factory.make_send(2000_i64)
        transaction.id = "123"

        transactions = [transaction]
        result = Validation::Transaction.validate_common(transactions, "testnet")
        result.passed.should be_empty
        result.failed.size.should eq(1)
        result.failed.first.reason.should eq("length of transaction id has to be 64: 123")
      end
    end

    it "should raise message size error if size > max" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block

        transaction = transaction_factory.make_send(2000_i64)
        transaction.message = ("exceeds"*100)

        transactions = [transaction]
        result = Validation::Transaction.validate_common(transactions, "testnet")
        result.passed.should be_empty
        result.failed.size.should eq(1)
        result.failed.first.reason.should eq("message size exceeds: 700 for 512")
      end
    end

    it "should raise token size error if size > max" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block

        transaction = transaction_factory.make_send(2000_i64)
        transaction.token = ("exceeds"*100)

        transactions = [transaction]
        result = Validation::Transaction.validate_common(transactions, "testnet")
        result.passed.should be_empty
        result.failed.size.should eq(1)
        result.failed.first.reason.should eq("token size exceeds: 700 for 16")
      end
    end

    it "should raise unscaled error if transaction is unscaled" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block

        transaction = transaction_factory.make_send(2000_i64)
        transaction.scaled = 0

        transactions = [transaction]
        result = Validation::Transaction.validate_common(transactions, "testnet")
        result.passed.should be_empty
        result.failed.size.should eq(1)
        result.failed.first.reason.should eq("unscaled transaction")
      end
    end

    it "should raise invalid signing for sender if sender not signed" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block

        transaction = transaction_factory.make_send(2000_i64)
        transaction = transaction.as_unsigned

        transactions = [transaction]
        result = Validation::Transaction.validate_common(transactions, "testnet")
        result.passed.should be_empty
        result.failed.size.should eq(1)
        result.failed.first.reason.should match(/string size should be 128, not 1/)
      end
    end

    it "should raise error if sender address is for wrong network" do
      with_factory do |_, transaction_factory|
        mainnet_sender_wallet = Wallet.from_json(Wallet.create(false).to_json)
        transaction = transaction_factory.make_send(1000_i64, "AXNT", mainnet_sender_wallet)
        transactions = [transaction]

        result = Validation::Transaction.validate_common(transactions, "testnet")
        result.passed.should be_empty
        result.failed.size.should eq(1)
        result.failed.first.reason.should eq("sender address: #{mainnet_sender_wallet.address} has wrong network type: mainnet, this node is running as: testnet")
      end
    end

    it "should raise error if recipient address is for wrong network" do
      with_factory do |block_factory, transaction_factory|
        mainnet_recipient_wallet = Wallet.from_json(Wallet.create(false).to_json)
        transaction = transaction_factory.make_send(1000_i64, "AXNT", block_factory.node_wallet, mainnet_recipient_wallet)
        transactions = [transaction]

        result = Validation::Transaction.validate_common(transactions, "testnet")
        result.passed.should be_empty
        result.failed.size.should eq(1)
        result.failed.first.reason.should eq("recipient address: #{mainnet_recipient_wallet.address} has wrong network type: mainnet, this node is running as: testnet")
      end
    end

    it "should raise checksum error if sender address checksum is invalid" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block

        invalid_sender = {
          address:    Base64.strict_encode("T0invalid-wallet-address"),
          public_key: transaction_factory.sender_wallet.public_key,
          amount:     1000_i64,
          fee:        1_i64,
          signature:  "0",
        }

        transaction = Transaction.new(
          Transaction.create_id,
          "send", # action
          [invalid_sender],
          [] of Transaction::Recipient,
          "0",           # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW,
          TransactionVersion::V1
        )

        transactions = [transaction]
        result = Validation::Transaction.validate_common(transactions, "testnet")
        result.passed.should be_empty
        result.failed.size.should eq(1)
        result.failed.first.reason.should eq("invalid sender address checksum for: VDBpbnZhbGlkLXdhbGxldC1hZGRyZXNz")
      end
    end

    it "should raise checksum error if recipient address checksum is invalid" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block

        invalid_recipient = {
          address: Base64.strict_encode("T0invalid-wallet-address"),
          amount:  1000_i64,
        }

        unsigned_transaction = Transaction.new(
          Transaction.create_id,
          "send", # action
          [a_sender(transaction_factory.sender_wallet, 1000_i64)],
          [invalid_recipient],
          "0",           # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW,
          TransactionVersion::V1
        )
        transaction = unsigned_transaction.as_signed([transaction_factory.sender_wallet])

        transactions = [transaction]
        result = Validation::Transaction.validate_common(transactions, "testnet")
        result.passed.should be_empty
        result.failed.size.should eq(1)
        result.failed.first.reason.should eq("invalid recipient address checksum for: VDBpbnZhbGlkLXdhbGxldC1hZGRyZXNz")
      end
    end
  end
end
