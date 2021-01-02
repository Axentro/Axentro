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

describe Blockchain do
  describe "setup" do
    it "should create a genesis block" do
      with_factory do |block_factory|
        block = block_factory.chain.first
        block.kind.should eq("SLOW")
        block.prev_hash.should eq("genesis")
      end
    end
  end

  describe "mining_block_difficulty_miner" do
    it "should return the miner difficulty" do
      with_factory do |block_factory|
        block_factory.blockchain.mining_block_difficulty_miner.should eq(0)
      end
    end
  end

  describe "mining_block_difficulty" do
    it "should return the chian difficulty" do
      with_factory do |block_factory|
        block_factory.blockchain.mining_block_difficulty.should eq(0)
      end
    end
  end

  describe "random block IDs for validation" do
    it "should return 20 random blocks from a 100 block chain by default" do
      with_factory do |block_factory|
        block_factory.add_slow_blocks(50).add_fast_blocks(50).chain
        blockchain = block_factory.blockchain
        random_blocks = blockchain.get_validation_block_ids(blockchain.latest_slow_block.index, blockchain.latest_fast_block_index_or_zero, 20_i64)
        random_blocks.size.should eq(101)
      end
    end
  end

  describe "replace_mixed_chain" do
    it "should return false if no subchains and do nothing" do
      with_factory do |block_factory|
        before = block_factory.chain
        block_factory.blockchain.replace_mixed_chain(nil).should eq(false)
        before.should eq(block_factory.chain)
      end
    end

    it "should return true and replace chain when fast and slow blocks in chain" do
      with_factory do |block_factory|
        chain = block_factory.add_slow_blocks(6).add_fast_blocks(10).chain
        fast_sub_chain = chain.select(&.is_fast_block?)
        slow_block_1 = chain[2].as(SlowBlock)
        slow_sub_chain = chain.select(&.is_slow_block?)

        database = Axentro::Core::Database.in_memory
        blockchain = Blockchain.new("testnet", block_factory.node_wallet, "", database, nil, nil, 20, 100, false, 512, true)
        blockchain.setup(block_factory.node)
        blockchain.push_slow_block(slow_block_1)
        expected = (blockchain.chain + slow_sub_chain[2..-1] + fast_sub_chain[0..-1]).map(&.index).sort
        blockchain.replace_mixed_chain(slow_sub_chain[2..-1] + fast_sub_chain[0..-1]).should eq(true)
        blockchain.chain.map(&.index).sort.should eq(expected)
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
        if reject = blockchain.rejects.find(transaction.id)
          reject.reason.should eq("the amount is out of range")
        else
          fail "no rejects found"
        end
      end
    end

    it "should not change the wallet balance for the default token with an arbitary action" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(10)
        address_amount = block_factory.database.get_address_amount(transaction_factory.recipient_wallet.address)
        address_amount.size.should eq(1)
        address_amount.first.amount.should eq(0)
        address_amount.first.token.should eq(TOKEN_DEFAULT)

        transaction = transaction_factory.make_transaction("something_stupid", 200000000_i64, "AXNT")
        block_factory.add_slow_block([transaction])
        address_amount = block_factory.database.get_address_amount(transaction_factory.recipient_wallet.address)
        address_amount.size.should eq(1)
        address_amount.first.amount.should eq(0)
        address_amount.first.token.should eq(TOKEN_DEFAULT)
      end
    end

    it "should not change the wallet balance for a custom token with an arbitary action" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(10)
        address_amount = block_factory.database.get_address_amount(transaction_factory.recipient_wallet.address)
        address_amount.size.should eq(1)
        address_amount.first.amount.should eq(0)
        address_amount.first.token.should eq(TOKEN_DEFAULT)

        transaction = transaction_factory.make_transaction("something_stupid", 200000000_i64, "KINGS")
        block_factory.add_slow_block([transaction])
        address_amount = block_factory.database.get_address_amount(transaction_factory.recipient_wallet.address)
        block_factory.blockchain.rejects.find(transaction.id).should be_nil
        address_amount.size.should eq(1)
        address_amount.first.amount.should eq(0)
        address_amount.first.token.should eq(TOKEN_DEFAULT)
      end
    end

    it "should reject a transaction when trying to fake the sender" do
      victim_wallet = Wallet.from_json(Wallet.create(true).to_json)
      hacker_wallet = Wallet.from_json(Wallet.create(true).to_json)

      sender = {address:    victim_wallet.address,
                public_key: hacker_wallet.public_key,
                amount:     10000000_i64,
                fee:        10000000_i64,
                signature:  "0",
      }

      recipient = {address: hacker_wallet.address,
                   amount:  10000000_i64}

      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "send", # action
        [sender],
        [recipient],
        "0",    # message
        "AXNT", # token
        "0",    # prev_hash
        0_i64,  # timestamp
        1,      # scaled
        TransactionKind::SLOW,
        TransactionVersion::V1
      )
      transaction = unsigned_transaction.as_signed([hacker_wallet])

      with_factory do |block_factory, _|
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        if reject = block_factory.blockchain.rejects.find(transaction.id)
          reject.reason.should eq("sender public key mismatch - sender public key: #{hacker_wallet.public_key} is not for sender address: #{victim_wallet.address}")
        else
          fail "no rejects found"
        end
      end
    end

    it "should reject a transaction when trying to fake the sender with senders public_key" do
      victim_wallet = Wallet.from_json(Wallet.create(true).to_json)
      hacker_wallet = Wallet.from_json(Wallet.create(true).to_json)

      sender = {address:    victim_wallet.address,
                public_key: victim_wallet.public_key,
                amount:     10000000_i64,
                fee:        10000000_i64,
                signature:  "0",
      }

      recipient = {address: hacker_wallet.address,
                   amount:  10000000_i64}

      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "send", # action
        [sender],
        [recipient],
        "0",    # message
        "AXNT", # token
        "0",    # prev_hash
        0_i64,  # timestamp
        1,      # scaled
        TransactionKind::SLOW,
        TransactionVersion::V1
      )
      transaction = unsigned_transaction.as_signed([hacker_wallet])

      with_factory do |block_factory, _|
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        if reject = block_factory.blockchain.rejects.find(transaction.id)
          reject.reason.should eq("invalid signing for sender: #{victim_wallet.address}")
        else
          fail "no rejects found"
        end
      end
    end

    it "should reject a transaction if already present" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(200000000_i64)
        block_factory.add_slow_blocks(6).add_slow_block([transaction]).add_slow_block([transaction])

        if reject = block_factory.blockchain.rejects.find(transaction.id)
          reject.reason.should eq("the transaction #{transaction.id} already exists in block: 14")
        else
          fail "no rejects found"
        end
      end
    end
  end

  describe "latest_block" do
    it "should return the latest block when slow" do
      with_factory do |block_factory|
        block_factory.add_slow_blocks(3)
        blockchain = block_factory.blockchain
        blockchain.latest_block.index.should eq(6)
      end
    end

    it "should return the latest block when fast" do
      with_factory do |block_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(4)
        blockchain = block_factory.blockchain
        blockchain.latest_block.index.should eq(7)
      end
    end
  end

  describe "latest_slow_block" do
    it "should return the latest slow block" do
      with_factory do |block_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(2)
        blockchain = block_factory.blockchain
        blockchain.latest_block.index.should eq(6)
      end
    end
  end

  describe "latest_index" do
    it "should return the latest index when slow" do
      with_factory do |block_factory|
        block_factory.add_slow_blocks(3)
        blockchain = block_factory.blockchain
        blockchain.latest_index.should eq(6)
      end
    end

    it "should return the latest index when fast" do
      with_factory do |block_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(4)
        blockchain = block_factory.blockchain
        blockchain.latest_index.should eq(7)
      end
    end
  end

  describe "get_latest_index_for_slow" do
    it "should return the latest index when slow" do
      with_factory do |block_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(4)
        blockchain = block_factory.blockchain
        blockchain.get_latest_index_for_slow.should eq(8)
      end
    end
  end

  describe "restore from database" do
    it "should load the whole chain from the database when the chain size is less than the memory allocation" do
      with_factory do |block_factory|
        block_factory.add_slow_blocks(10)
        database = block_factory.database
        blockchain = Blockchain.new("testnet", block_factory.node_wallet, "", database, nil, nil, 20, 100, false, 512, true)
        blockchain.setup(block_factory.node)
        # including genesis block total chain size should be 11
        blockchain.chain.size.should eq(11)
      end
    end
    it "should load a subset of the whole chain from the database when the chain size is more than the memory allocation" do
      with_factory do |block_factory|
        blocks_to_add = block_factory.blocks_to_hold + 8
        block_factory.add_slow_blocks(blocks_to_add)
        database = block_factory.database
        blockchain = Blockchain.new("testnet", block_factory.node_wallet, "", database, nil, nil, 20, 100, false, 512, true)
        blockchain.setup(block_factory.node)
        # including genesis block total chain size should be the number of blocks to hold
        blockchain.chain.size.should eq(blockchain.blocks_to_hold)
      end
    end
  end

  describe "available_actions" do
    it "should return available actions" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(3).add_fast_blocks(4).add_slow_block([transaction_factory.make_send(200000000_i64)])
        blockchain = block_factory.blockchain
        blockchain.available_actions.should eq(["send", "hra_buy", "hra_sell", "hra_cancel", "create_token", "update_token", "lock_token", "burn_token"])
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

        # this transaction is already in the db so change it's id
        coinbase_transaction = block_factory.chain.last.transactions.first
        coinbase_transaction.id = Transaction.create_id

        blockchain.align_slow_transactions(coinbase_transaction, 1, 8, block_factory.blockchain.embedded_slow_transactions).size.should eq(2)
      end
    end

    it "should not include rejected transactions in the coinbase amount" do
      with_factory do |block_factory, transaction_factory|
        blockchain = block_factory.blockchain
        block_factory.add_slow_blocks(2, false).add_fast_blocks(4).add_slow_block([transaction_factory.make_send(200000000_i64)], false)
        blockchain.refresh_mining_block(8)

        # this transaction is already in the db so change it's id
        coinbase_transaction = block_factory.chain.last.transactions.first
        coinbase_transaction.id = Transaction.create_id

        # add a transaction to embedded that will be rejected (not enough funds) and coinbase amount should not add the rejected transactions fee
        aligned = blockchain.align_slow_transactions(coinbase_transaction, 1, 8, block_factory.blockchain.embedded_slow_transactions + [transaction_factory.make_send(90000000000000_i64)])
        aligned.first.recipients.map(&.["amount"]).sum.should eq(1200007495)
      end
    end
  end

  describe "create_coinbase_slow_transaction" do
    it "should create a slow coinbase transaction" do
      with_factory do |block_factory, transaction_factory|
        blockchain = block_factory.blockchain
        block_factory.add_slow_blocks(2).add_fast_blocks(4).add_slow_block([transaction_factory.make_send(200000000_i64)])
        amount = 200000000_i64
        transaction = blockchain.create_coinbase_slow_transaction(amount, 0_i64, [block_factory.miner])
        transaction.action.should eq("head")
        recipient = transaction.recipients.first
        recipient[:address].should eq(block_factory.node_wallet.address)
        recipient[:amount].should eq(amount)
      end
    end

    it "should create a slow coinbase transaction with fastnode fees" do
      with_factory do |block_factory, transaction_factory|
        blockchain = block_factory.blockchain
        block_factory.add_slow_blocks(2).add_fast_blocks(4).add_slow_block([transaction_factory.make_send(200000000_i64)])
        amount = 200000000_i64
        fastnode_fees = 10_i64
        transaction = blockchain.create_coinbase_slow_transaction(amount, fastnode_fees, [block_factory.miner])
        transaction.action.should eq("head")
        recipient = transaction.recipients.first
        recipient[:address].should eq(block_factory.node_wallet.address)
        recipient[:amount].should eq(amount + fastnode_fees)
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
        if reject = blockchain.rejects.find(transaction2.id)
          reject.reason.should eq("the amount is out of range")
        else
          fail "no rejects found"
        end
      end
    end
  end

  it "align transactions" do
    with_factory do |block_factory, transaction_factory|
      transaction_total = 10
      transactions = (1..transaction_total).to_a.map { |n| transaction_factory.make_send(n.to_i64) }

      block_factory.add_slow_block(transactions, false)
      block_factory.blockchain.embedded_slow_transactions.size.should eq(transaction_total)
      coinbase_transaction = block_factory.blockchain.chain.last.transactions.first

      result = Benchmark.measure {
        block_factory.blockchain.align_slow_transactions(coinbase_transaction, 1, 2, block_factory.blockchain.embedded_slow_transactions)
      }

      (result.real < 0.010).should be_true
    end
  end

  it "clean transactions" do
    with_factory do |block_factory, transaction_factory|
      transaction_total = 10
      transactions = (1..transaction_total).to_a.map { |n| transaction_factory.make_send(n.to_i64) }

      block_factory.add_slow_block(transactions, false)
      block_factory.blockchain.pending_slow_transactions.size.should eq(transaction_total)

      result = Benchmark.measure {
        block_factory.blockchain.clean_slow_transactions
      }

      (result.real < 0.010).should be_true
    end
  end
end
