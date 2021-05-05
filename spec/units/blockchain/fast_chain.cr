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

describe Blockchain do
  describe "valid_transactions_for_fast_block" do
    it "should the latest index and valid aligned transactions" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_fast_send(200000000_i64)
        transaction2 = transaction_factory.make_fast_send(200000000_i64)
        blockchain = block_factory.blockchain

        block_factory.add_slow_blocks(4)

        transaction1.id
        transaction2.id

        blockchain.add_transaction(transaction1, false)
        blockchain.add_transaction(transaction2, false)

        result = blockchain.valid_transactions_for_fast_block
        result[:transactions].size.should eq(3)
        result[:latest_index].should eq(1)
      end
    end
  end

  describe "mint_fast_block" do
    it "should mint a fast block" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_fast_send(200000000_i64)
        transaction2 = transaction_factory.make_fast_send(200000000_i64)
        blockchain = block_factory.blockchain
        coinbase_transaction = blockchain.create_coinbase_fast_transaction(4000000000_i64)
        valid_transactions = {latest_index: 1_i64, transactions: [coinbase_transaction, transaction1, transaction2]}
        block = blockchain.mint_fast_block(valid_transactions)
        block.index.should eq(1)
      end
    end
  end

  describe "align_fast_transactions" do
    it "should align the fast transactions" do
      with_factory do |block_factory, transaction_factory|
        blockchain = block_factory.blockchain
        block_factory.add_slow_blocks(4)

        blockchain.add_transaction(transaction_factory.make_fast_send(200000000_i64), false)
        blockchain.add_transaction(transaction_factory.make_fast_send(200000000_i64), false)
        blockchain.add_transaction(transaction_factory.make_fast_send(200000000_i64), false)
        coinbase_transaction = blockchain.create_coinbase_fast_transaction(30000_i64)

        aligned = blockchain.align_fast_transactions(coinbase_transaction, 1, block_factory.blockchain.embedded_fast_transactions)
        aligned.size.should eq(4)

        aligned[0].prev_hash.should eq("0")
        aligned[1].prev_hash.should eq(aligned[0].to_hash)
        aligned[2].prev_hash.should eq(aligned[1].to_hash)
        aligned[3].prev_hash.should eq(aligned[2].to_hash)
      end
    end
  end

  describe "create_coinbase_fast_transaction" do
    it "should create a fast coinbase transaction" do
      with_factory do |block_factory, transaction_factory|
        blockchain = block_factory.blockchain
        block_factory.add_slow_blocks(2).add_fast_blocks(4).add_fast_block([transaction_factory.make_fast_send(200000000_i64)])
        amount = 200000000_i64
        transaction = blockchain.create_coinbase_fast_transaction(amount)
        transaction.action.should eq("head")
        recipient = transaction.recipients.first
        recipient.address.should eq(block_factory.node_wallet.address)
        recipient.amount.should eq(amount)
      end
    end
  end

  describe "coinbase_fast_amount" do
    it "should calculate the reward based on fees" do
      with_factory do |block_factory, transaction_factory|
        blockchain = block_factory.blockchain
        amount = 200000000_i64
        block_factory.add_slow_blocks(4)
          .add_fast_blocks(4)
          .add_slow_block([transaction_factory.make_fast_send(amount), transaction_factory.make_fast_send(amount)])
        transactions = blockchain.embedded_fast_transactions
        blockchain.coinbase_fast_amount(1, transactions).should eq(20000)
      end
    end
  end

  describe "replace_fast_transactions" do
    it "should validate and add new transactions that have arrived" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_fast_send(200000000_i64)
        transaction2 = transaction_factory.make_fast_send(300000000_i64)
        blockchain = block_factory.blockchain
        blockchain.pending_fast_transactions.size.should eq(0)
        blockchain.replace_fast_transactions([transaction1, transaction2])
        blockchain.pending_fast_transactions.size.should eq(2)
      end
    end

    it "should reject any invalid transactions" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_fast_send(400000000_i64)
        transaction2 = transaction_factory.make_fast_send(-500000000_i64)
        blockchain = block_factory.blockchain

        blockchain.pending_fast_transactions.size.should eq(0)
        blockchain.replace_fast_transactions([transaction1, transaction2])
        blockchain.pending_fast_transactions.size.should eq(1)
        if reject = blockchain.rejects.find(transaction2.id)
          reject.reason.should eq("the amount is out of range")
        else
          fail "no rejects found"
        end
      end
    end
  end
end
