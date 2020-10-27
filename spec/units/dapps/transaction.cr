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

include Axentro::Core
include Units::Utils
include Axentro::Core::DApps::BuildIn
include Axentro::Core::Controllers

describe TransactionCreator do
  describe "default non implemented methods" do
    it "should perform #setup" do
      with_factory do |block_factory, _|
        transaction_creator = TransactionCreator.new(block_factory.add_slow_block.blockchain)
        transaction_creator.setup.should be_nil
      end
    end
    it "should perform #transaction_actions" do
      with_factory do |block_factory, _|
        transaction_creator = TransactionCreator.new(block_factory.add_slow_block.blockchain)
        transaction_creator.transaction_actions.size.should eq(0)
      end
    end
    it "should perform #transaction_related?" do
      with_factory do |block_factory, _|
        transaction_creator = TransactionCreator.new(block_factory.add_slow_block.blockchain)
        transaction_creator.transaction_related?("action").should be_false
      end
    end
    it "should perform #valid_transaction?" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(2).chain
        transaction_creator = TransactionCreator.new(block_factory.blockchain)
        result = transaction_creator.valid_transactions?(chain.last.transactions)
        result.failed.size.should eq(0)
        result.passed.size.should eq(0)
      end
    end
    it "should perform #record" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(2).chain
        transaction_creator = TransactionCreator.new(block_factory.blockchain)
        transaction_creator.record(chain).should be_nil
      end
    end
    it "should perform #clear" do
      with_factory do |block_factory, _|
        transaction_creator = TransactionCreator.new(block_factory.add_slow_blocks(2).blockchain)
        transaction_creator.clear.should be_nil
      end
    end
  end

  describe "#define_rpc?" do
    describe "#create_unsigned_transaction" do
      it "should return the transaction as json when valid" do
        with_factory do |block_factory, transaction_factory|
          senders = [a_decimal_sender(transaction_factory.sender_wallet, "1")]
          recipients = [a_decimal_recipient(transaction_factory.recipient_wallet, "10")]

          payload = {
            call:       "create_unsigned_transaction",
            action:     "send",
            senders:    senders,
            recipients: recipients,
            message:    "",
            token:      TOKEN_DEFAULT,
            kind:       "SLOW",
          }.to_json

          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            expected_senders = [a_sender(transaction_factory.sender_wallet, 100000000_i64)]
            expected_recipients = [a_recipient(transaction_factory.recipient_wallet, 1000000000_i64)]

            transaction = Transaction.from_json(result)
            transaction.action.should eq("send")
            transaction.prev_hash.should eq("0")
            transaction.message.should eq("")
            transaction.senders.should eq(expected_senders)
            transaction.recipients.should eq(expected_recipients)
            transaction.kind.should eq(TransactionKind::SLOW)
          end
        end
      end

      describe "#create_transaction" do
        it "should return a signed transaction when valid" do
          with_factory do |block_factory, transaction_factory|
            senders = [a_sender(transaction_factory.sender_wallet, 1000_i64)]
            recipients = [a_recipient(transaction_factory.recipient_wallet, 100_i64)]

            unsigned_transaction = Transaction.new(
              Transaction.create_id,
              "send", # action
              senders,
              recipients,
              "0",           # message
              TOKEN_DEFAULT, # token
              "0",           # prev_hash
              0_i64,         # timestamp
              1,             # scaled
              TransactionKind::SLOW
            )

            signed_transaction = unsigned_transaction.as_signed([transaction_factory.sender_wallet])

            payload = {
              call:        "create_transaction",
              transaction: signed_transaction,
            }.to_json

            json = JSON.parse(payload)

            with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
              transaction = Transaction.from_json(result)
              transaction.action.should eq("send")
              transaction.prev_hash.should eq("0")
              transaction.message.should eq("0")
              transaction.senders.first["signature"].should_not eq("0")
              transaction.senders.should_not eq(senders)
            end
          end
        end

        it "should return a 403 when an Exception occurs" do
          with_factory do |block_factory, transaction_factory|
            [a_sender(transaction_factory.sender_wallet, 1000_i64)]
            [a_recipient(transaction_factory.recipient_wallet, 100_i64)]

            payload = {
              call:    "create_transaction",
              missing: "missing",
            }.to_json

            json = JSON.parse(payload)

            with_rpc_exec_internal_post(block_factory.rpc, json, 403) do |res|
              res.includes?(%{Missing hash key: "transaction"}).should be_true
            end
          end
        end
      end
    end
  end
end
