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

include Units::Utils
include Sushi::Core
include Sushi::Core::TransactionModels
include ::Sushi::Common::Denomination
include ::Sushi::Core::NodeComponents
include Hashes

TOTAL_BLOCK_REWARD = 50462650_i64

describe Blockchain do
  it "should calculate the block rewards for a single miner" do
    with_factory do |block_factory, _|
      miner1 = {context: {address: "Miner 1", nonces: [1_u64, 2_u64] of UInt64}, socket: MockWebSocket.new, mid: "miner1"}
      coinbase_amount = block_factory.blockchain.coinbase_amount(0, [] of Transaction)
      transaction = block_factory.blockchain.create_coinbase_transaction(coinbase_amount, [miner1])

      node_reward = get_recipient_for(transaction.recipients, block_factory.node_wallet.address)[:amount]
      miner1_reward = get_recipient_for(transaction.recipients, "Miner 1")[:amount]

      node_reward.should eq(12615663_i64)
      as_percentage(node_reward).should eq(25)

      miner1_reward.should eq(37846987_i64)
      as_percentage(miner1_reward).should eq(75)

      (node_reward + miner1_reward).should eq(TOTAL_BLOCK_REWARD)
    end
  end

  it "should calculate the block rewards for multiple miners" do
    with_factory do |block_factory, _|
      miner1 = {context: {address: "Miner 1", nonces: [1_u64, 2_u64] of UInt64}, socket: MockWebSocket.new, mid: "miner1"}
      miner2 = {context: {address: "Miner 2", nonces: [1_u64, 2_u64] of UInt64}, socket: MockWebSocket.new, mid: "miner2"}
      miner3 = {context: {address: "Miner 3", nonces: [1_u64, 2_u64] of UInt64}, socket: MockWebSocket.new, mid: "miner3"}
      coinbase_amount = block_factory.blockchain.coinbase_amount(0, [] of Transaction)
      transaction = block_factory.blockchain.create_coinbase_transaction(coinbase_amount, [miner1, miner2, miner3])

      node_reward = get_recipient_for(transaction.recipients, block_factory.node_wallet.address)[:amount]
      miner1_reward = get_recipient_for(transaction.recipients, "Miner 1")[:amount]
      miner2_reward = get_recipient_for(transaction.recipients, "Miner 2")[:amount]
      miner3_reward = get_recipient_for(transaction.recipients, "Miner 3")[:amount]

      node_reward.should eq(12615664_i64)
      as_percentage(node_reward).should eq(25)

      miner1_reward.should eq(12615662_i64)
      as_percentage(miner1_reward).should eq(25)

      miner2_reward.should eq(12615662_i64)
      as_percentage(miner2_reward).should eq(25)

      miner3_reward.should eq(12615662_i64)
      as_percentage(miner3_reward).should eq(25)

      (node_reward + miner1_reward + miner2_reward + miner3_reward).should eq(TOTAL_BLOCK_REWARD)
    end
  end

  it "should reward miners according to their contribution (node always gets 25%)" do
    assert_reward_distribution(1, 2, 25, 50)
    assert_reward_distribution(1, 3, 19, 56)
    assert_reward_distribution(1, 4, 15, 60)
    assert_reward_distribution(1, 5, 12, 62)
    assert_reward_distribution(1, 6, 11, 64)
    assert_reward_distribution(1, 7, 9, 66)
    assert_reward_distribution(1, 70, 1, 74)
    assert_reward_distribution(1, 150, 0, 75) # miner 1 got no reward
  end

  it "should not allocate rewards if the total supply has been reached" do
    fail("implement this")
  end

  STDERR.puts "< Block Rewards"
end

def assert_reward_distribution(nonces1, nonces2, expected_percent_1, expected_percent_2)
  with_factory do |block_factory, _|
    miner1 = {context: {address: "Miner 1", nonces: (1..nonces1).map { |n| n.to_u64 }}, socket: MockWebSocket.new, mid: "miner1"}
    miner2 = {context: {address: "Miner 2", nonces: (1..nonces2).map { |n| n.to_u64 }}, socket: MockWebSocket.new, mid: "miner2"}
    coinbase_amount = block_factory.blockchain.coinbase_amount(0, [] of Transaction)
    transaction = block_factory.blockchain.create_coinbase_transaction(coinbase_amount, [miner1, miner2])

    node_reward = get_recipient_for(transaction.recipients, block_factory.node_wallet.address)[:amount]
    miner1_reward = get_recipient_for(transaction.recipients, "Miner 1")[:amount]
    miner2_reward = get_recipient_for(transaction.recipients, "Miner 2")[:amount]

    as_percentage(node_reward).should eq(25)
    as_percentage(miner1_reward).should eq(expected_percent_1)
    as_percentage(miner2_reward).should eq(expected_percent_2)

    (node_reward + miner1_reward + miner2_reward).should eq(TOTAL_BLOCK_REWARD)
  end
end

def get_recipient_for(recipients, address)
  recipients.find { |r| r[:address] == address }.not_nil!
end

def as_percentage(percent_of)
  ((percent_of.to_f64 / TOTAL_BLOCK_REWARD.to_f64) * 100).round.to_i32
end
