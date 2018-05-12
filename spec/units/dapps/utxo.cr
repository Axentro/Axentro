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

describe UTXO do
  describe "#get" do
    it "should return 0 when the number of blocks is less than confirmations" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
        utxo.record(chain)

        address = chain[1].transactions.first.recipients.first[:address]
        utxo.get(address, TOKEN_DEFAULT).should eq(0)
      end
    end

    it "should return address amount when the number of blocks is greater than confirmations" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(10).chain
        utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
        utxo.record(chain)

        address = chain[1].transactions.first.recipients.first[:address]
        expected_amount = chain[1].transactions[0].recipients[0]["amount"]

        utxo.get(address, TOKEN_DEFAULT).should eq(expected_amount)
      end
    end

    context "when address does not exist" do
      it "should return 0 when the number of blocks is less than confirmations and the address is not found" do
        with_factory do |block_factory, transaction_factory|
          chain = block_factory.addBlock.chain
          utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
          utxo.record(chain)

          utxo.get("address-does-not-exist", TOKEN_DEFAULT).should eq(0)
        end
      end

      it "should return address amount when the number of blocks is greater than confirmations and the address is not found" do
        with_factory do |block_factory, transaction_factory|
          chain = block_factory.addBlocks(10).chain
          utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
          utxo.record(chain)

          utxo.get("address-does-not-exist", TOKEN_DEFAULT).should eq(0)
        end
      end
    end

    context "when token does not exist" do
      it "should return 0 when the number of blocks is less than confirmations and the token is not found" do
        with_factory do |block_factory, transaction_factory|
          chain = block_factory.addBlock.chain
          utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
          utxo.record(chain)
          address = chain[1].transactions.first.recipients.first[:address]

          utxo.get(address, "UNKNOWN").should eq(0)
        end
      end

      it "should return address amount when the number of blocks is greater than confirmations and the token is not found" do
        with_factory do |block_factory, transaction_factory|
          chain = block_factory.addBlocks(10).chain
          utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
          utxo.record(chain)
          address = chain[1].transactions.first.recipients.first[:address]

          utxo.get(address, "UNKNOWN").should eq(0)
        end
      end
    end
  end

  describe "#get_unconfirmed" do
    it "should get unconfirmed transactions amount for the supplied address in the supplied transactions" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
        utxo.record(chain)

        transactions = chain.reject { |blk| blk.prev_hash == "genesis" }.flat_map { |blk| blk.transactions }
        address = chain[1].transactions.first.recipients.first[:address]
        expected_amount = transactions.flat_map { |txn| txn.recipients.select { |r| r[:address] == address } }.map { |x| x[:amount] }.sum * 2
        utxo.get_unconfirmed(address, transactions, TOKEN_DEFAULT).should eq(expected_amount)
      end
    end

    it "should get unconfirmed transactions amount for the supplied address when no transactions are supplied" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
        utxo.record(chain)

        transactions = [] of Transaction
        address = chain[1].transactions.first.recipients.first[:address]
        expected_amount = chain.reject { |blk| blk.prev_hash == "genesis" }.flat_map { |blk| blk.transactions.first.recipients.select { |r| r[:address] == address } }.map { |x| x[:amount] }.sum
        utxo.get_unconfirmed(address, transactions, TOKEN_DEFAULT).should eq(expected_amount)
      end
    end

    context "when chain is empty" do
      it "should get unconfirmed transactions amount for the supplied address when no transactions are supplied and the chain is empty" do
        with_factory do |block_factory, transaction_factory|
          chain = [] of Block
          utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
          utxo.record(chain)

          transactions = [] of Transaction
          address = "any-address"
          utxo.get_unconfirmed(address, transactions, TOKEN_DEFAULT).should eq(0)
        end
      end

      it "should get unconfirmed transactions when no transactions are supplied and the chain is empty and the address is unknown" do
        with_factory do |block_factory, transaction_factory|
          chain = [] of Block
          utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
          utxo.record(chain)

          transactions = [] of Transaction
          utxo.get_unconfirmed("address-does-not-exist", transactions, TOKEN_DEFAULT).should eq(0)
        end
      end
    end
  end

  describe "#transaction_actions" do
    it "should return actions" do
      with_factory do |block_factory, transaction_factory|
        utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
        utxo.transaction_actions.should eq(["send"])
      end
    end
  end

  describe "#transaction_related?" do
    it "should always return true" do
      with_factory do |block_factory, transaction_factory|
        utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
        utxo.transaction_related?("whatever").should be_true
      end
    end
  end

  describe "#valid_transaction?" do
    it "should return true if valid transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(100_i64)
        transaction2 = transaction_factory.make_send(200_i64)
        chain = block_factory.addBlock.chain
        utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
        utxo.record(chain)
        utxo.valid_transaction?(transaction2, [transaction1]).should be_true
      end
    end

    it "should raise an error if has a recipient" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(100_i64)
        transaction2 = transaction_factory.make_send(200_i64)
        chain = block_factory.addBlock.chain
        utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
        transaction2.recipients = [a_recipient(transaction_factory.recipient_wallet, 10_i64), a_recipient(transaction_factory.recipient_wallet, 10_i64)]
        utxo.record(chain)
        expect_raises(Exception, "there must be 1 or less recipients") do
          utxo.valid_transaction?(transaction2, [transaction1])
        end
      end
    end

    it "should raise an error if has no senders" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(100_i64)
        transaction2 = transaction_factory.make_send(200_i64)
        chain = block_factory.addBlock.chain
        utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
        transaction2.senders = [] of Transaction::Sender
        utxo.record(chain)
        expect_raises(Exception, "there must be 1 sender") do
          utxo.valid_transaction?(transaction2, [transaction1])
        end
      end
    end

    it "should raise an error if sender has not enough default token to afford the transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(100000000_i64)
        transaction2 = transaction_factory.make_send(200000000_i64)
        chain = block_factory.addBlock.chain
        utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))

        utxo.record(chain)
        expect_raises(Exception, "sender has not enough token(#{TOKEN_DEFAULT}). sender has -88716210 + 0 but try to pay 2000000") do
          utxo.valid_transaction?(transaction2, [transaction1])
        end
      end
    end

    it "should raise an error if sender has not enough default token to afford the transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(1000000_i64, "KINGS")
        transaction2 = transaction_factory.make_send(2000000_i64, "KINGS")
        chain = block_factory.addBlock.chain
        utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))

        utxo.record(chain)
        expect_raises(Exception, "sender has not enough token(KINGS). sender has -1000000 + 0 but try to pay 2000000") do
          utxo.valid_transaction?(transaction2, [transaction1])
        end
      end
    end
  end

  describe "#calculate_for_transaction" do
    it "should return the utxo for a transaction with default token" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(100_i64)
        transaction2 = transaction_factory.make_send(200_i64)
        chain = block_factory.addBlock.chain
        utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
        utxo.record(chain)
        expected = {TOKEN_DEFAULT => {"#{transaction_factory.sender_wallet.address}" => -201_i64, "#{transaction_factory.recipient_wallet.address}" => 200_i64}}
        utxo.calculate_for_transaction(transaction2).should eq(expected)
      end
    end

    it "should return the utxo for a transaction with custom token" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(100_i64, "KINGS")
        transaction2 = transaction_factory.make_send(200_i64, "KINGS")
        chain = block_factory.addBlock.chain
        utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
        utxo.record(chain)
        expected = {"KINGS"       => {"#{transaction_factory.sender_wallet.address}" => -200_i64, "#{transaction_factory.recipient_wallet.address}" => 200_i64},
                    TOKEN_DEFAULT => {"#{transaction_factory.sender_wallet.address}" => -1_i64},
        }
        utxo.calculate_for_transaction(transaction2).should eq(expected)
      end
    end
  end

  describe "#calculate_for_transactions" do
    it "should return utxo for transactions with mixed tokens" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(100_i64, "KINGS")
        transaction2 = transaction_factory.make_send(200_i64)
        chain = block_factory.addBlock.chain
        utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
        utxo.record(chain)
        expected = {"KINGS"       => {"#{transaction_factory.sender_wallet.address}" => -100_i64, "#{transaction_factory.recipient_wallet.address}" => 100_i64},
                    TOKEN_DEFAULT => {"#{transaction_factory.sender_wallet.address}" => -202_i64, "#{transaction_factory.recipient_wallet.address}" => 200_i64}}
        utxo.calculate_for_transactions([transaction1, transaction2]).should eq(expected)
      end
    end
  end

  describe "#create_token" do
    it "should create a custom token" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
        utxo.record(chain)
        utxo.@utxo_internal.reject(&.empty?).flat_map { |t| t.keys }.should eq([TOKEN_DEFAULT])
        utxo.create_token(transaction_factory.sender_wallet.address, 1200_i64, "KINGS")
        utxo.@utxo_internal.reject(&.empty?).flat_map { |t| t.keys }.should eq([TOKEN_DEFAULT, "KINGS"])
      end
    end
  end

  describe "#clear" do
    it "should clear the internal transaction lists with #clear" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(10).chain
        utxo = UTXO.new(blockchain_node(transaction_factory.sender_wallet))
        utxo.record(chain)

        utxo.@utxo_internal.size.should eq(11)
        utxo.clear
        utxo.@utxo_internal.size.should eq(0)
      end
    end
  end

  describe "#define_rpc?" do
    describe "#amount" do
      it "should return the unconfirmed amount" do
        with_factory do |block_factory, transaction_factory|
          block_factory.addBlocks(10)
          recipient_address = block_factory.chain.last.transactions.first.recipients.first[:address]
          payload = {call: "amount", address: recipient_address, confirmed: false, token: TOKEN_DEFAULT}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            result.should eq(%{{"confirmed":false,"pairs":[{"token":"SUSHI","amount":112837910}]}})
          end
        end
      end

      it "should return the confirmed amount" do
        with_factory do |block_factory, transaction_factory|
          block_factory.addBlocks(10)
          recipient_address = block_factory.chain.last.transactions.first.recipients.first[:address]
          payload = {call: "amount", address: recipient_address, confirmed: true, token: TOKEN_DEFAULT}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            result.should eq(%{{"confirmed":true,"pairs":[{"token":"SUSHI","amount":11283791}]}})
          end
        end
      end
    end
  end

  it "should return fee when calling #Self.fee" do
    UTXO.fee("send").should eq(1_i64)
  end

  STDERR.puts "< dApps::UTXO"
end
