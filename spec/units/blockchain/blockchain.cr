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
  describe "setup" do
    it "should create a genesis block" do
      with_factory do |block_factory, transaction_factory|
        block = block_factory.chain.first
        block.kind.should eq("SLOW")
        block.prev_hash.should eq("genesis")
      end
    end
  end

  describe "mining_block_difficulty_miner" do
    it "should return the miner difficulty" do
      with_factory do |block_factory, transaction_factory|
        block_factory.blockchain.mining_block_difficulty_miner.should eq(11)
      end
    end
  end

  describe "mining_block_difficulty" do
    it "should return the chian difficulty" do
      with_factory do |block_factory, transaction_factory|
        block_factory.blockchain.mining_block_difficulty.should eq(0)
      end
    end
  end

  describe "replace_chain" do
    it "should return false if no subchains and do nothing" do
      with_factory do |block_factory, transaction_factory|
        before = block_factory.chain
        block_factory.blockchain.replace_chain(nil, nil).should eq(false)
        before.should eq(block_factory.chain)
      end
    end

    it "should return true and replace slow chain" do
      with_factory do |block_factory, transaction_factory|
        before = block_factory.chain
        sub_chain = block_factory.add_slow_blocks(10).chain

        blockchain = Blockchain.new(block_factory.node_wallet, nil, nil)
        blockchain.setup(block_factory.node)

        blockchain.replace_chain(sub_chain[1..-1], nil).should eq(true)
        blockchain.chain.should eq(sub_chain[1..-1])
      end
    end
  end

  describe "add_transaction" do
    it "should add a transaction to the pool" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(200000000_i64)
        blockchain = block_factory.blockchain
        blockchain.add_transaction(transaction, false)
        blockchain.pending_slow_transactions.first.should eq(transaction)
        blockchain.embedded_slow_transactions.first.should eq(transaction)
      end
    end

    it "should reject a transaction if invalid" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(-200000000_i64)
        blockchain = block_factory.blockchain
        blockchain.add_transaction(transaction, false)
        blockchain.pending_slow_transactions.size.should eq(0)
        blockchain.embedded_slow_transactions.size.should eq(0)
        blockchain.rejects.find(transaction.id).should eq("the amount is out of range")
      end
    end

    it "should reject a transaction if already present" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(200000000_i64)
        block_factory.add_slow_block([transaction]).add_slow_blocks(3)
        blockchain = block_factory.blockchain
        blockchain.add_transaction(transaction, false)
        blockchain.add_transaction(transaction, false)
        block_factory.add_slow_blocks(2)
        blockchain.pending_slow_transactions.size.should eq(0)
        blockchain.embedded_slow_transactions.size.should eq(0)
        blockchain.rejects.find(transaction.id).should eq("the transaction #{transaction.id} is already included in 2")
      end
    end
  end

  describe "latest_block" do
    it "should return the latest block when slow" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3)
        blockchain = block_factory.blockchain
        blockchain.latest_block.index.should eq(6)
      end
    end

    it "should return the latest block when fast" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(4)
        blockchain = block_factory.blockchain
        blockchain.latest_block.index.should eq(7)
      end
    end
  end

  describe "latest_slow_block" do
    it "should return the latest slow block" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(2)
        blockchain = block_factory.blockchain
        blockchain.latest_block.index.should eq(6)
      end
    end
  end

  describe "latest_index" do
    it "should return the latest index when slow" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3)
        blockchain = block_factory.blockchain
        blockchain.latest_index.should eq(6)
      end
    end

    it "should return the latest index when fast" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(4)
        blockchain = block_factory.blockchain
        blockchain.latest_index.should eq(7)
      end
    end
  end

  describe "get_latest_index_for_slow" do
    it "should return the latest index when slow" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(4)
        blockchain = block_factory.blockchain
        blockchain.get_latest_index_for_slow.should eq(8)
      end
    end
  end

  describe "subchain_slow" do
    it "should return the slow subchain" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(4)
        blockchain = block_factory.blockchain
        indexes = blockchain.subchain_slow(0).not_nil!.map(&.index)
        indexes.should eq([0, 2, 4, 6])
      end
    end
  end

  describe "headers" do
    it "should return the headers" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(4)
        blockchain = block_factory.blockchain
        header_indexes = blockchain.headers.map(&.["index"])
        header_indexes.should eq([0, 1, 2, 3, 4, 5, 6, 7])
      end
    end
  end

  describe "transactions_for_address" do
    it "should return all transactions for address" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(4).add_slow_block([transaction_factory.make_send(200000000_i64)])
        blockchain = block_factory.blockchain
        all = blockchain.transactions_for_address(block_factory.node_wallet.address)
        all.size.should eq(5)
      end
    end

    it "should return 'send' transactions for address" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(4).add_slow_block([transaction_factory.make_send(200000000_i64)])
        blockchain = block_factory.blockchain
        all = blockchain.transactions_for_address(block_factory.node_wallet.address, 0, 20, ["send"])
        all.size.should eq(1)
      end
    end

    it "should return paginated transactions for address" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(5).add_fast_blocks(5).add_slow_block([transaction_factory.make_send(200000000_i64)])
        blockchain = block_factory.blockchain
        blockchain.transactions_for_address(block_factory.node_wallet.address, 0, 3).size.should eq(3)
        blockchain.transactions_for_address(block_factory.node_wallet.address, 2, 1).size.should eq(1)
      end
    end
  end

  describe "available_actions" do
    it "should return 'send' transactions for address" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(4).add_slow_block([transaction_factory.make_send(200000000_i64)])
        blockchain = block_factory.blockchain
        blockchain.available_actions.should eq(["send", "scars_buy", "scars_sell", "scars_cancel", "create_token"])
      end
    end
  end

  describe "refresh_slow_pending_block" do
    it "should refresh the pending block" do
      with_factory do |block_factory, transaction_factory|
        blockchain = block_factory.blockchain
        blockchain.mining_block.index.should eq(2)
        block_factory.add_slow_blocks(2, false).add_slow_block([transaction_factory.make_send(200000000_i64)], false)
        blockchain.refresh_mining_block(8)
        blockchain.mining_block.index.should eq(8)
      end
    end
  end

  describe "align_slow_transactions" do
    it "should align the slow transactions" do
      with_factory do |block_factory, transaction_factory|
        blockchain = block_factory.blockchain
        block_factory.add_slow_blocks(2, false).add_fast_blocks(4).add_slow_block([transaction_factory.make_send(200000000_i64)], false)
        blockchain.refresh_mining_block(8)
        coinbase_transaction = block_factory.chain.last.transactions.first
        blockchain.align_slow_transactions(coinbase_transaction, 1).size.should eq(2)
      end
    end
  end

  describe "create_coinbase_slow_transaction" do
    it "should create a slow coinbase transaction" do
      with_factory do |block_factory, transaction_factory|
        blockchain = block_factory.blockchain
        block_factory.add_slow_blocks(2).add_fast_blocks(4).add_slow_block([transaction_factory.make_send(200000000_i64)])
        coinbase_transaction = block_factory.chain.last.transactions.first
        amount = 200000000_i64
        transaction = blockchain.create_coinbase_slow_transaction(amount, [block_factory.miner])
        transaction.action.should eq("head")
        recipient = transaction.recipients.first
        recipient[:address].should eq(block_factory.node_wallet.address)
        recipient[:amount].should eq(amount)
      end
    end
  end

  describe "coinbase_slow_amount" do
    it "should calculate the reward excluding fees (transactions are not taken into account)" do
      with_factory do |block_factory, transaction_factory|
        blockchain = block_factory.blockchain
        amount = 200000000_i64
        block_factory.add_slow_blocks(2)
          .add_fast_blocks(4)
          .add_slow_block([transaction_factory.make_send(amount), transaction_factory.make_send(amount)])
        transactions = blockchain.embedded_slow_transactions
        blockchain.coinbase_slow_amount(0, transactions).should eq(1200000000)
      end
    end

    it "should calculate the reward based on fees (no more minable blocks so all rewards come from fees)" do
      with_factory do |block_factory, transaction_factory|
        blockchain = block_factory.blockchain
        amount = 200000000_i64
        block_factory.add_slow_blocks(2, false)
          .add_fast_blocks(4)
          .add_slow_block([transaction_factory.make_send(amount), transaction_factory.make_send(amount)], false)
        transactions = blockchain.embedded_slow_transactions
        blockchain.coinbase_slow_amount(blockchain.@block_reward_calculator.max_blocks + 1, transactions).should eq(20000)
      end
    end
  end

  describe "total_fees" do
    it "should calculate the total fees based on the transactions" do
      with_factory do |block_factory, transaction_factory|
        blockchain = block_factory.blockchain
        amount = 200000000_i64
        block_factory.add_slow_blocks(2, false)
          .add_fast_blocks(4)
          .add_slow_block([transaction_factory.make_send(amount), transaction_factory.make_send(amount)], false)
        transactions = blockchain.embedded_slow_transactions
        blockchain.total_fees(transactions).should eq(20000)
      end
    end
  end

  describe "replace_slow_transactions" do
    it "should validate and add new transactions that have arrived" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(200000000_i64)
        transaction2 = transaction_factory.make_send(300000000_i64)
        blockchain = block_factory.blockchain
        blockchain.pending_slow_transactions.size.should eq(0)
        blockchain.replace_slow_transactions([transaction1, transaction2])
        blockchain.pending_slow_transactions.size.should eq(2)
      end
    end

    it "should reject any invalid transactions" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(200000000_i64)
        transaction2 = transaction_factory.make_send(-300000000_i64)
        blockchain = block_factory.blockchain
        blockchain.pending_slow_transactions.size.should eq(0)
        blockchain.replace_slow_transactions([transaction1, transaction2])
        blockchain.pending_slow_transactions.size.should eq(1)
        blockchain.rejects.find(transaction2.id).should eq("the amount is out of range")
      end
    end
  end

  it "align transactions" do
    with_factory do |block_factory, transaction_factory|
      transaction_total = 10
      transactions = (1..transaction_total).to_a.map{|n| transaction_factory.make_send(n.to_i64) }

      block_factory.add_slow_block(transactions, false)
      block_factory.blockchain.embedded_slow_transactions.size.should eq(transaction_total)
      coinbase_transaction = block_factory.blockchain.chain.last.transactions.first

      puts Benchmark.measure {
        block_factory.blockchain.align_slow_transactions(coinbase_transaction, 1)
      }
    end
  end

  it "clean transactions" do
    with_factory do |block_factory, transaction_factory|
      transaction_total = 10
      transactions = (1..transaction_total).to_a.map{|n| transaction_factory.make_send(n.to_i64) }

      block_factory.add_slow_block(transactions, false)
      block_factory.blockchain.pending_slow_transactions.size.should eq(transaction_total)

      puts Benchmark.measure {
        block_factory.blockchain.clean_slow_transactions
      }
    end
  end
end
