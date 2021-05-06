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
      [] of Transaction::Asset,
      [] of Transaction::Module,
      [] of Transaction::Input,
      [] of Transaction::Output,
      "",            # linked
      "0",           # message
      TOKEN_DEFAULT, # token
      "0",           # prev_hash
      0_i64,         # timestamp
      1,             # scaled
      TransactionKind::SLOW,
      TransactionVersion::V1
    )

    transaction.action.should eq("send")
    senders = transaction.senders
    senders.size.should eq(1)
    senders.first.address.should eq(sender_wallet.address)
    senders.first.public_key.should eq(sender_wallet.public_key)
    senders.first.amount.should eq(1000_i64)

    recipients = transaction.recipients
    recipients.size.should eq(1)
    recipients.first.address.should eq(recipient_wallet.address)
    recipients.first.amount.should eq(10_i64)

    transaction.id.should eq(transaction_id)
    transaction.message.should eq("0")
    transaction.prev_hash.should eq("0")
  end

  it "should add the signatures to the transaction using #as_signed" do
    with_factory do |_|
      sender_wallet = Wallet.from_json(Wallet.create(true).to_json)

      unsigned_transaction = Transaction.new(
        Transaction.create_id,
        "send", # action
        [a_sender(sender_wallet, 10001_i64)],
        [] of Transaction::Recipient,
        [] of Transaction::Asset,
        [] of Transaction::Module,
        [] of Transaction::Input,
        [] of Transaction::Output,
        "",            # linked
        "0",           # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        0_i64,         # timestamp
        1,             # scaled
        TransactionKind::SLOW,
        TransactionVersion::V1
      )

      signed_transaction = unsigned_transaction.as_signed([sender_wallet])

      signed_transaction.senders.first.signature.should_not eq("0")
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
        [] of Transaction::Asset,
        [] of Transaction::Module,
        [] of Transaction::Input,
        [] of Transaction::Output,
        "",            # linked
        "0",           # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        0_i64,         # timestamp
        1,             # scaled
        TransactionKind::SLOW,
        TransactionVersion::V1
      )

      signed_transaction = unsigned_transaction.as_signed([sender_wallet])

      signed_transaction.senders.first.signature.should_not eq("0")

      unsigned = signed_transaction.as_unsigned
      unsigned.senders.first.signature.should eq("0")
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
        [] of Transaction::Asset,
        [] of Transaction::Module,
        [] of Transaction::Input,
        [] of Transaction::Output,
        "",            # linked
        "0",           # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        0_i64,         # timestamp
        1,             # scaled
        TransactionKind::SLOW,
        TransactionVersion::V1
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
        [] of Transaction::Asset,
        [] of Transaction::Module,
        [] of Transaction::Input,
        [] of Transaction::Output,
        "",            # linked
        "0",           # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        0_i64,         # timestamp
        1,             # scaled
        TransactionKind::SLOW,
        TransactionVersion::V1
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
        [] of Transaction::Asset,
        [] of Transaction::Module,
        [] of Transaction::Input,
        [] of Transaction::Output,
        "",            # linked
        "0",           # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        0_i64,         # timestamp
        1,             # scaled
        TransactionKind::SLOW,
        TransactionVersion::V1
      )

      transaction.total_fees.should eq(10000_i64)
    end
  end
end
