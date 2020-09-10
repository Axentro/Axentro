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

require "./../../spec_helper"

include Units::Utils
include Axentro::Core
include Axentro::Core::TransactionModels
include Hashes

describe Transaction do
  it "should create a transaction id of length 64" do
    Transaction.create_id.size.should eq(64)
  end

  it "should create a new unsigned transaction" do
    sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
    recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)

    transaction_id = Transaction.create_id
    transaction = Transaction.new(
      transaction_id,
      "send", # action
      [a_sender(sender_wallet, 1000_i64)],
      [a_recipient(recipient_wallet, 10_i64)],
      "0",           # message
      TOKEN_DEFAULT, # token
      "0",           # prev_hash
      0_i64,         # timestamp
      1,             # scaled
      TransactionKind::SLOW
    )

    transaction.action.should eq("send")
    senders = transaction.senders
    senders.size.should eq(1)
    senders.first[:address].should eq(sender_wallet.address)
    senders.first[:public_key].should eq(sender_wallet.public_key)
    senders.first[:amount].should eq(1000_i64)

    recipients = transaction.recipients
    recipients.size.should eq(1)
    recipients.first[:address].should eq(recipient_wallet.address)
    recipients.first[:amount].should eq(10_i64)

    transaction.id.should eq(transaction_id)
    transaction.message.should eq("0")
    transaction.prev_hash.should eq("0")
  end

  describe "#valid_as_embedded?" do
    it "should return true when valid" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.add_slow_block([transaction_factory.make_send(2000_i64)]).chain
        transactions = chain.last.transactions

        transaction = transaction_factory.make_send(1000_i64)
        transaction.valid_common?.should be_true
        transaction.prev_hash = transactions.last.to_hash
        transaction.valid_as_embedded?(block_factory.blockchain, transactions).should be_true
      end
    end

    it "should raise not checked signing if not common checked" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.add_slow_block([transaction_factory.make_send(2000_i64)]).chain
        transactions = chain.last.transactions

        transaction = transaction_factory.make_send(1000_i64)
        expect_raises(Exception, "transactions have not been validated") do
          transaction.valid_as_embedded?(block_factory.blockchain, transactions)
        end
      end
    end

    it "should raise amount mismatch for senders and recipients if they are not equal" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.add_slow_block([transaction_factory.make_send(2000_i64)]).chain
        transactions = chain.last.transactions

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
          TransactionKind::SLOW
        )
        transaction = unsigned_transaction.as_signed([sender_wallet])
        transaction.valid_common?.should be_true

        transaction.prev_hash = transactions.last.to_hash
        expect_raises(Exception, "amount mismatch for senders (0.0004) and recipients (0.0001)") do
          transaction.valid_as_embedded?(block_factory.blockchain, transactions)
        end
      end
    end

    it "should raise invalid prev hash if prev hash is invalid" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.add_slow_block([transaction_factory.make_send(2000_i64)]).chain
        transactions = chain.last.transactions

        transaction = transaction_factory.make_send(2000_i64)
        transaction.valid_common?.should be_true
        transaction.prev_hash = "123"

        expect_raises(Exception, /invalid prev_hash:/) do
          transaction.valid_as_embedded?(block_factory.blockchain, transactions)
        end
      end
    end
  end

  describe "#valid_as_coinbase?" do
    it "should return true when valid" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.add_slow_block([transaction_factory.make_send(2000_i64)]).chain
        transactions = chain.last.transactions

        transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Transaction::Sender,
          [a_recipient(transaction_factory.recipient_wallet, 1199999686_i64)],
          "0",           # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW
        )

        transaction.valid_common?.should be_true
        transaction.valid_as_coinbase?(block_factory.blockchain, 1, transactions).should be_true
      end
    end

    it "should raise not checked signing if not common checked" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.add_slow_block([transaction_factory.make_send(2000_i64)]).chain
        transactions = chain.last.transactions

        transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Transaction::Sender,
          [a_recipient(transaction_factory.recipient_wallet, 1199999373_i64)],
          "0",           # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW
        )

        expect_raises(Exception, "transactions have not been validated") do
          transaction.valid_as_coinbase?(block_factory.blockchain, 1, transactions)
        end
      end
    end

    it "should raise action error if not set to 'head'" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.add_slow_block([transaction_factory.make_send(2000_i64)]).chain
        transactions = chain.last.transactions

        transaction = Transaction.new(
          Transaction.create_id,
          "invalid", # action
          [] of Transaction::Sender,
          [a_recipient(transaction_factory.recipient_wallet, 1199999373_i64)],
          "0",           # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW
        )

        transaction.valid_common?.should be_true
        expect_raises(Exception, "actions has to be 'head' for coinbase transaction") do
          transaction.valid_as_coinbase?(block_factory.blockchain, 1, transactions)
        end
      end
    end

    it "should raise message error if not set to '0'" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.add_slow_block([transaction_factory.make_send(2000_i64)]).chain
        transactions = chain.last.transactions

        transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Transaction::Sender,
          [a_recipient(transaction_factory.recipient_wallet, 1199999373_i64)],
          "invalid",     # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW
        )

        transaction.valid_common?.should be_true
        expect_raises(Exception, "message has to be '0' for coinbase transaction") do
          transaction.valid_as_coinbase?(block_factory.blockchain, 1, transactions)
        end
      end
    end

    it "should raise token error if not set to AXNT" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.add_slow_block([transaction_factory.make_send(2000_i64)]).chain
        transactions = chain.last.transactions

        transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Transaction::Sender,
          [a_recipient(transaction_factory.recipient_wallet, 1199999373_i64)],
          "0",       # message
          "INVALID", # token
          "0",       # prev_hash
          0_i64,     # timestamp
          1,         # scaled
          TransactionKind::SLOW
        )

        transaction.valid_common?.should be_true
        expect_raises(Exception, "token has to be AXNT for coinbase transaction") do
          transaction.valid_as_coinbase?(block_factory.blockchain, 1, transactions)
        end
      end
    end

    it "should raise sender error if a sender is provided" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.add_slow_block([transaction_factory.make_send(2000_i64)]).chain
        transactions = chain.last.transactions

        transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Transaction::Sender,
          [a_recipient(transaction_factory.recipient_wallet, 1199999373_i64)],
          "0",           # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW
        )

        transaction.valid_common?.should be_true
        transaction.senders = [a_sender(transaction_factory.sender_wallet, 1000_i64)]
        expect_raises(Exception, "there should be no Sender for a coinbase transaction") do
          transaction.valid_as_coinbase?(block_factory.blockchain, 1, transactions)
        end
      end
    end

    it "should raise prev hash error if not set to '0'" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.add_slow_block([transaction_factory.make_send(2000_i64)]).chain
        transactions = chain.last.transactions

        transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Transaction::Sender,
          [a_recipient(transaction_factory.recipient_wallet, 1199999373_i64)],
          "0",           # message
          TOKEN_DEFAULT, # token
          "1",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW
        )

        transaction.valid_common?.should be_true
        expect_raises(Exception, "prev_hash of coinbase transaction has to be '0'") do
          transaction.valid_as_coinbase?(block_factory.blockchain, 1, transactions)
        end
      end
    end

    it "should raise invalid served amount if the served amount does not equal the served sum" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.add_slow_block([transaction_factory.make_send(2000_i64)]).chain
        transactions = chain.last.transactions

        transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Transaction::Sender,
          [a_recipient(transaction_factory.recipient_wallet, 1000_i64)],
          "0",           # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW
        )

        transaction.valid_common?.should be_true
        expect_raises(Exception, "invalid served amount for coinbase transaction at index: 1 expected 1199999686 but got 1000") do
          transaction.valid_as_coinbase?(block_factory.blockchain, 1, transactions).should be_true
        end
      end
    end
  end

  describe "#valid_common?" do
    it "should return true when valid" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block([transaction_factory.make_send(2000_i64)])

        transaction = transaction_factory.make_send(2000_i64)
        transaction.valid_common?.should be_true
      end
    end

    it "should raise transaction id length error if not 64" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block([transaction_factory.make_send(2000_i64)])

        transaction = transaction_factory.make_send(2000_i64)
        transaction.id = "123"
        expect_raises(Exception, "length of transaction id has to be 64: 123") do
          transaction.valid_common?
        end
      end
    end

    it "should raise message size error if size > max" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block([transaction_factory.make_send(2000_i64)])

        transaction = transaction_factory.make_send(2000_i64)
        transaction.message = ("exceeds"*100)
        expect_raises(Exception, "message size exceeds: 700 for 512") do
          transaction.valid_common?
        end
      end
    end

    it "should raise token size error if size > max" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block([transaction_factory.make_send(2000_i64)])

        transaction = transaction_factory.make_send(2000_i64)
        transaction.token = ("exceeds"*100)
        expect_raises(Exception, "token size exceeds: 700 for 16") do
          transaction.valid_common?
        end
      end
    end

    it "should raise unscaled error if transaction is unscaled" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block([transaction_factory.make_send(2000_i64)])

        transaction = transaction_factory.make_send(2000_i64)
        transaction.scaled = 0
        expect_raises(Exception, "unscaled transaction") do
          transaction.valid_common?
        end
      end
    end

    it "should raise invalid signing for sender if sender not signed" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block([transaction_factory.make_send(2000_i64)])

        transaction = transaction_factory.make_send(2000_i64)
        transaction = transaction.as_unsigned
        expect_raises(Exception, /string size should be 128, not 1/) do
          transaction.valid_common?
        end
      end
    end

    it "should raise checksum error if sender address checksum is invalid" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block([transaction_factory.make_send(2000_i64)])

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
          TransactionKind::SLOW
        )
        expect_raises(Exception, "invalid sender address checksum for: VDBpbnZhbGlkLXdhbGxldC1hZGRyZXNz") do
          transaction.valid_common?
        end
      end
    end

    it "should raise checksum error if recipient address checksum is invalid" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_block([transaction_factory.make_send(2000_i64)])

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
          TransactionKind::SLOW
        )
        transaction = unsigned_transaction.as_signed([transaction_factory.sender_wallet])
        expect_raises(Exception, "invalid recipient address checksum for: VDBpbnZhbGlkLXdhbGxldC1hZGRyZXNz") do
          transaction.valid_common?
        end
      end
    end
  end

  it "should add the signatures to the transaction using #as_signed" do
    with_factory do |_|
      sender_wallet = Wallet.from_json(Wallet.create(true).to_json)

      unsigned_transaction = Transaction.new(
        Transaction.create_id,
        "send", # action
        [a_sender(sender_wallet, 10001_i64)],
        [] of Transaction::Recipient,
        "0",           # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        0_i64,         # timestamp
        1,             # scaled
        TransactionKind::SLOW
      )

      signed_transaction = unsigned_transaction.as_signed([sender_wallet])

      signed_transaction.senders.first["signature"].should_not eq("0")
    end
  end

  it "should transform a signed transaction to an unsigned one using #as_unsigned" do
    with_factory do |_|
      sender_wallet = Wallet.from_json(Wallet.create(true).to_json)

      unsigned_transaction = Transaction.new(
        Transaction.create_id,
        "send", # action
        [a_sender(sender_wallet, 10001_i64)],
        [] of Transaction::Recipient,
        "0",           # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        0_i64,         # timestamp
        1,             # scaled
        TransactionKind::SLOW
      )

      signed_transaction = unsigned_transaction.as_signed([sender_wallet])

      signed_transaction.senders.first["signature"].should_not eq("0")

      unsigned = signed_transaction.as_unsigned
      unsigned.senders.first["signature"].should eq("0")
    end
  end

  it "should get the sender amount with #sender_total_amount" do
    with_factory do |_, transaction_factory|
      sender_wallet = transaction_factory.sender_wallet
      recipient_wallet = transaction_factory.recipient_wallet

      transaction = Transaction.new(
        Transaction.create_id,
        "send", # action
        [a_sender(sender_wallet, 10_i64)],
        [a_recipient(recipient_wallet, 10_i64)],
        "0",           # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        0_i64,         # timestamp
        1,             # scaled
        TransactionKind::SLOW
      )

      transaction.sender_total_amount.should eq(10_i64)
    end
  end

  it "should get the recipient amount with #recipient_total_amount" do
    with_factory do |_, transaction_factory|
      sender_wallet = transaction_factory.sender_wallet
      recipient_wallet = transaction_factory.recipient_wallet

      transaction = Transaction.new(
        Transaction.create_id,
        "send", # action
        [a_sender(sender_wallet, 10_i64)],
        [a_recipient(recipient_wallet, 10_i64)],
        "0",           # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        0_i64,         # timestamp
        1,             # scaled
        TransactionKind::SLOW
      )

      transaction.recipient_total_amount.should eq(10_i64)
    end
  end

  it "should get the sender fee amount with #total_fees" do
    with_factory do |_, transaction_factory|
      sender_wallet = transaction_factory.sender_wallet
      recipient_wallet = transaction_factory.recipient_wallet

      transaction = Transaction.new(
        Transaction.create_id,
        "send", # action
        [a_sender(sender_wallet, 11_i64)],
        [a_recipient(recipient_wallet, 10_i64)],
        "0",           # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        0_i64,         # timestamp
        1,             # scaled
        TransactionKind::SLOW
      )

      transaction.total_fees.should eq(10000_i64)
    end
  end
end
