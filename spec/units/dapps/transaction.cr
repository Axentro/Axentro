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
include Units::Utils
include Sushi::Core::DApps::BuildIn
include Sushi::Core::Controllers

describe TransactionCreator do
  describe "default non implemented methods" do
    it "should perform #setup" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        transaction_creator = TransactionCreator.new(blockchain_node(transaction_factory.sender_wallet))
        transaction_creator.setup.should be_nil
      end
    end
    it "should perform #transaction_actions" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        transaction_creator = TransactionCreator.new(blockchain_node(transaction_factory.sender_wallet))
        transaction_creator.transaction_actions.size.should eq(0)
      end
    end
    it "should perform #transaction_related?" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        transaction_creator = TransactionCreator.new(blockchain_node(transaction_factory.sender_wallet))
        transaction_creator.transaction_related?("action").should be_false
      end
    end
    it "should perform #valid_transaction?" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(2).chain
        transaction_creator = TransactionCreator.new(blockchain_node(transaction_factory.sender_wallet))
        transaction_creator.valid_transaction?(chain.last.transactions.first, chain.last.transactions).should be_true
      end
    end
    it "should perform #record" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(2).chain
        transaction_creator = TransactionCreator.new(blockchain_node(transaction_factory.sender_wallet))
        transaction_creator.record(chain).should be_nil
      end
    end
    it "should perform #clear" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(2).chain
        transaction_creator = TransactionCreator.new(blockchain_node(transaction_factory.sender_wallet))
        transaction_creator.clear.should be_nil
      end
    end
  end

  describe "#define_rpc?" do
    describe "#create_unsigned_transaction" do
      it "should return the transaction as json when valid" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          senders = [a_sender(sender_wallet, 1000_i64)]
          recipients = [a_recipient(recipient_wallet, 10_i64)]

          payload = {
            call:       "create_unsigned_transaction",
            action:     "send",
            senders:    senders,
            recipients: recipients,
            message:    "",
            token:      TOKEN_DEFAULT,
          }.to_json

          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |result|
            transaction = Transaction.from_json(result)
            transaction.action.should eq("send")
            transaction.prev_hash.should eq("0")
            transaction.message.should eq("")
            transaction.sign_r.should eq("0")
            transaction.sign_s.should eq("0")
            transaction.senders.should eq(senders)
            transaction.recipients.should eq(recipients)
          end
        end
      end

      describe "#create_transaction" do
        it "should return a signed transaction when valid" do
          with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
            senders = [a_sender(sender_wallet, 1000_i64)]
            recipients = [a_recipient(recipient_wallet, 100_i64)]

            unsigned_transaction = Transaction.new(
              Transaction.create_id,
              "send", # action
              senders,
              recipients,
              "0",           # message
              TOKEN_DEFAULT, # token
              "0",           # prev_hash
              "0",           # sign_r
              "0",           # sign_s
            )

            signature = sign(sender_wallet, unsigned_transaction)
            signed_transaction = unsigned_transaction.signed(signature[:r], signature[:s])

            payload = {
              call:        "create_transaction",
              transaction: signed_transaction,
            }.to_json

            json = JSON.parse(payload)

            with_rpc_exec_internal_post(rpc, json) do |result|
              transaction = Transaction.from_json(result)
              transaction.action.should eq("send")
              transaction.prev_hash.should eq("0")
              transaction.message.should eq("0")
              transaction.sign_r.should eq(signature[:r])
              transaction.sign_s.should eq(signature[:s])
              transaction.senders.should eq(senders)
            end
          end
        end

        it "should return a 403 when an Exception occurs" do
          with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
            senders = [a_sender(sender_wallet, 1000_i64)]
            recipients = [a_recipient(recipient_wallet, 100_i64)]

            payload = {
              call:    "create_transaction",
              missing: "missing",
            }.to_json

            json = JSON.parse(payload)

            with_rpc_exec_internal_post(rpc, json, 403) do |res|
              res.includes?(%{Missing hash key: "transaction"}).should be_true
            end
          end
        end
      end
    end
  end
    STDERR.puts "< dApps::TransactionCreator"
end
