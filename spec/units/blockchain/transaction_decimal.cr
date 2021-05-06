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

describe TransactionDecimal do
  it "should create a new unsigned decimal transaction" do
    sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
    recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)

    transaction_id = Transaction.create_id
    transaction = TransactionDecimal.new(
      transaction_id,
      "send", # action
      [a_decimal_sender(sender_wallet, "1000000")],
      [a_decimal_recipient(recipient_wallet, "1000000")],
      [] of Transaction::Asset,
      [] of Transaction::Module,
      [] of Transaction::Input,
      [] of Transaction::Output,
      "",            # linked
      "0",           # message
      TOKEN_DEFAULT, # token
      "0",           # prev_hash
      0_i64,         # timestamp
      0,             # scaled
      TransactionKind::SLOW,
      TransactionVersion::V1
    )

    transaction.action.should eq("send")
    senders = transaction.senders
    senders.size.should eq(1)
    senders.first.address.should eq(sender_wallet.address)
    senders.first.public_key.should eq(sender_wallet.public_key)
    senders.first.amount.should eq("1000000")

    recipients = transaction.recipients
    recipients.size.should eq(1)
    recipients.first.address.should eq(recipient_wallet.address)
    recipients.first.amount.should eq("1000000")

    transaction.id.should eq(transaction_id)
    transaction.message.should eq("0")
    transaction.prev_hash.should eq("0")
  end

  it "should raise scaled error on create if unscaled" do
    sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
    recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)

    transaction_id = Transaction.create_id
    expect_raises(Exception, "invalid decimal transaction (expected scaled: 0 but received 1)") do
      TransactionDecimal.new(
        transaction_id,
        "send", # action
        [a_decimal_sender(sender_wallet, "1000000")],
        [a_decimal_recipient(recipient_wallet, "1000000")],
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
    end
  end

  it "should convert to a non decimal transaction" do
    transaction_id = Transaction.create_id
    sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
    recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)

    transaction = TransactionDecimal.new(
      transaction_id,
      "send", # action
      [a_decimal_sender(sender_wallet, "1000000")],
      [a_decimal_recipient(recipient_wallet, "1000000")],
      [] of Transaction::Asset,
      [] of Transaction::Module,
      [] of Transaction::Input,
      [] of Transaction::Output,
      "",            # linked
      "0",           # message
      TOKEN_DEFAULT, # token
      "0",           # prev_hash
      0_i64,         # timestamp
      0,             # scaled
      TransactionKind::SLOW,
      TransactionVersion::V1
    )
    non_decimal = transaction.to_transaction
    typeof(non_decimal).should eq(Axentro::Core::Transaction)
  end
end
