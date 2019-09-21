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

include Units::Utils
include Sushi::Core
include Sushi::Core::TransactionModels
include Hashes

describe SlowTransactionPool do
  it "should create an instance of the pool" do
    SlowTransactionPool.setup
    SlowTransactionPool.instance.should_not be_nil
  end

  it "should add a transaction to the pool using static methods" do
    with_factory do |_, transaction_factory|
      transaction = transaction_factory.make_send(2000_i64)

      SlowTransactionPool.setup
      SlowTransactionPool.all.size.should eq(0)
      SlowTransactionPool.add(transaction)
      SlowTransactionPool.all.size.should eq(1)
    end
  end

  it "should add a transaction to the pool using instance methods" do
    with_factory do |_, transaction_factory|
      transaction = transaction_factory.make_send(2000_i64)

      pool = SlowTransactionPool.setup
      pool.all.size.should eq(0)
      pool.add(transaction)
      pool.all.size.should eq(1)
    end
  end

  it "should insert a transaction" do
    with_factory do |_, transaction_factory|
      transaction = transaction_factory.make_send(2000_i64)

      pool = SlowTransactionPool.setup
      pool.all.size.should eq(0)
      pool.insert(transaction)
      pool.all.size.should eq(1)
    end
  end

  it "should delete a transaction using static methods" do
    with_factory do |_, transaction_factory|
      transaction = transaction_factory.make_send(2000_i64)

      SlowTransactionPool.setup
      SlowTransactionPool.all.size.should eq(0)
      SlowTransactionPool.add(transaction)
      SlowTransactionPool.all.size.should eq(1)

      SlowTransactionPool.delete(transaction)
      SlowTransactionPool.all.size.should eq(0)
    end
  end

  it "should delete a transaction using instance methods" do
    with_factory do |_, transaction_factory|
      transaction = transaction_factory.make_send(2000_i64)

      pool = SlowTransactionPool.setup
      pool.all.size.should eq(0)
      pool.add(transaction)
      pool.all.size.should eq(1)

      pool.delete(transaction)
      pool.all.size.should eq(0)
    end
  end

  it "should replace the transactions using static methods" do
    with_factory do |_, transaction_factory|
      transaction1 = transaction_factory.make_send(1000_i64)
      transaction2 = transaction_factory.make_send(2000_i64)
      transaction3 = transaction_factory.make_send(3000_i64)

      SlowTransactionPool.setup
      SlowTransactionPool.all.size.should eq(0)
      SlowTransactionPool.add(transaction1)
      SlowTransactionPool.all.size.should eq(1)

      SlowTransactionPool.replace([transaction2, transaction3])
      SlowTransactionPool.all.size.should eq(2)
      SlowTransactionPool.find(transaction1).should be_nil
      SlowTransactionPool.find(transaction2).should_not be_nil
      SlowTransactionPool.find(transaction3).should_not be_nil
    end
  end

  it "should replace the transactions using instance methods" do
    with_factory do |_, transaction_factory|
      transaction1 = transaction_factory.make_send(1000_i64)
      transaction2 = transaction_factory.make_send(2000_i64)
      transaction3 = transaction_factory.make_send(3000_i64)

      pool = SlowTransactionPool.setup
      pool.all.size.should eq(0)
      pool.add(transaction1)
      pool.all.size.should eq(1)

      pool.replace([transaction2, transaction3])
      pool.all.size.should eq(2)
      pool.find(transaction1).should be_nil
      pool.find(transaction2).should_not be_nil
      pool.find(transaction3).should_not be_nil
    end
  end

  it "should embed using static methods" do
    with_factory do |_, transaction_factory|
      SlowTransactionPool.setup

      transactions = (0..2001).map do
        Transaction.new(
          Transaction.create_id,
          "send", # action
          [a_sender(transaction_factory.sender_wallet, 1000_i64)],
          [a_recipient(transaction_factory.recipient_wallet, 1000_i64)],
          "0",           # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW
        )
      end

      SlowTransactionPool.replace(transactions)
      SlowTransactionPool.all.size.should eq(2002)
      SlowTransactionPool.embedded.size.should eq(2000)
    end
  end

  it "should embed using instance methods" do
    with_factory do |_, transaction_factory|
      pool = SlowTransactionPool.setup
      transactions = (0..2001).map do
        Transaction.new(
          Transaction.create_id,
          "send", # action
          [a_sender(transaction_factory.sender_wallet, 1000_i64)],
          [a_recipient(transaction_factory.recipient_wallet, 1000_i64)],
          "0",           # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          1,             # scaled
          TransactionKind::SLOW
        )
      end

      pool.replace(transactions)
      pool.all.size.should eq(2002)
      pool.embedded.size.should eq(2000)
    end
  end

  it "should lock using static methods" do
    with_factory do |_, transaction_factory|
      transaction1 = transaction_factory.make_send(2000_i64)
      transaction2 = transaction_factory.make_send(2000_i64)
      SlowTransactionPool.setup
      SlowTransactionPool.replace([transaction1]) # clear the pools
      SlowTransactionPool.lock
      SlowTransactionPool.add(transaction1)
      SlowTransactionPool.all.size.should eq(1)
      SlowTransactionPool.replace([transaction2])
      SlowTransactionPool.all.size.should eq(2)
    end
  end

  it "should lock using instance methods" do
    with_factory do |_, transaction_factory|
      transaction1 = transaction_factory.make_send(2000_i64)
      transaction2 = transaction_factory.make_send(2000_i64)
      pool = SlowTransactionPool.setup
      pool.replace([transaction1]) # clear the pools
      pool.lock
      pool.add(transaction1)
      pool.all.size.should eq(1)
      pool.replace([transaction2])
      pool.all.size.should eq(2)
    end
  end

  STDERR.puts "< SlowTransactionPool"
end
