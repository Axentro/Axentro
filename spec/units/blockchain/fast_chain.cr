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
require "benchmark"

include Sushi::Core
include Hashes
include Units::Utils
include Sushi::Core::DApps::BuildIn
include Sushi::Core::Controllers
include Sushi::Core::Block

describe Blockchain do
  describe "latest_fast_block" do
    it "should return the latest fast block" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(2)
        blockchain = block_factory.blockchain
        blockchain.latest_fast_block.not_nil!.index.should eq(3)
      end
    end

    it "should return nil if no fast blocks" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3)
        blockchain = block_factory.blockchain
        blockchain.latest_fast_block.should be(nil)
      end
    end
  end

  describe "latest_fast_block_index_or_zero" do
    it "should return the latest fast block index" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(2)
        blockchain = block_factory.blockchain
        blockchain.latest_fast_block_index_or_zero.should eq(3)
      end
    end

    it "should return 0 if no fast blocks" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3)
        blockchain = block_factory.blockchain
        blockchain.latest_fast_block_index_or_zero.should eq(0)
      end
    end
  end

  describe "get_latest_index_for_fast" do
    it "should return the next fast block index when 0" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3)
        blockchain = block_factory.blockchain
        blockchain.get_latest_index_for_fast.should eq(1)
      end
    end

    it "should return the next fast block index when odd" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(2)
        blockchain = block_factory.blockchain
        blockchain.get_latest_index_for_fast.should eq(5)
      end
    end
  end

  describe "subchain_fast" do
    it "should return the fast subchain" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(4)
        blockchain = block_factory.blockchain
        indexes = blockchain.subchain_fast(0).not_nil!.map(&.index)
        indexes.should eq([1, 3, 5, 7])
      end
    end
  end

  describe "valid_transactions_for_fast_block" do
    it "should the latest index and valid aligned transactions" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_fast_send(200000000_i64)
        transaction2 = transaction_factory.make_fast_send(200000000_i64)
        blockchain = block_factory.blockchain

        block_factory.add_slow_blocks(2)

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
        coinbase_transaction = blockchain.create_coinbase_fast_transaction(4000000000_i64)

        blockchain.align_fast_transactions(coinbase_transaction, 1).size.should eq(4)
      end
    end
  end

  # describe "create_coinbase_fast_transaction" do
  #   it "should create a slow coinbase transaction" do
  #     with_factory do |block_factory, transaction_factory|
  #       blockchain = block_factory.blockchain
  #       block_factory.add_slow_blocks(2).add_fast_blocks(4).add_slow_block([transaction_factory.make_send(200000000_i64)])
  #       coinbase_transaction = block_factory.chain.last.transactions.first
  #       amount = 200000000_i64
  #       transaction = blockchain.create_coinbase_slow_transaction(amount, [block_factory.miner])
  #       transaction.action.should eq("head")
  #       recipient = transaction.recipients.first
  #       recipient[:address].should eq(block_factory.node_wallet.address)
  #       recipient[:amount].should eq(amount)
  #     end
  #   end
  # end

  # describe "coinbase_slow_amount" do
  #   it "should calculate the reward excluding fees (transactions are not taken into account)" do
  #     with_factory do |block_factory, transaction_factory|
  #       blockchain = block_factory.blockchain
  #       amount = 200000000_i64
  #       block_factory.add_slow_blocks(2)
  #         .add_fast_blocks(4)
  #         .add_slow_block([transaction_factory.make_send(amount), transaction_factory.make_send(amount)])
  #       transactions = blockchain.embedded_slow_transactions
  #       blockchain.coinbase_slow_amount(0, transactions).should eq(1200000000)
  #     end
  #   end
  #
  #   it "should calculate the reward based on fees (no more minable blocks so all rewards come from fees)" do
  #     with_factory do |block_factory, transaction_factory|
  #       blockchain = block_factory.blockchain
  #       amount = 200000000_i64
  #       block_factory.add_slow_blocks(2, false)
  #         .add_fast_blocks(4)
  #         .add_slow_block([transaction_factory.make_send(amount), transaction_factory.make_send(amount)], false)
  #       transactions = blockchain.embedded_slow_transactions
  #       blockchain.coinbase_slow_amount(blockchain.@block_reward_calculator.max_blocks + 1, transactions).should eq(20000)
  #     end
  #   end
  # end
end
