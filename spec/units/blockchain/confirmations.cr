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
  it "it should get the number of confirmations for a transaction with just slow blocks" do
    with_factory do |block_factory, transaction_factory|
      block_factory.add_slow_blocks(1)
      sleep 0.001
      block_factory.add_slow_blocks(1)
      sleep 0.001
      block_factory.add_slow_block([transaction_factory.make_send(1)])
      sleep 0.001
      block_factory.add_slow_blocks(1)
      sleep 0.001
      block_factory.add_slow_blocks(1)

      block_factory.blockchain.wallet_info.wallet_info_impl(block_factory.node_wallet.address).recent_transactions.each do |rt|
        block_info = block_factory.blockchain.blockchain_info.block_transaction_impl(false, rt.transaction_id)
        res = block_info.as(NamedTuple(block: Axentro::Core::Block, confirmations: Int32))

        case rt.confirmations.to_i
        when 0
          res[:block].index.should eq(10)
        when 1
          res[:block].index.should eq(8)
        when 2
          res[:block].index.should eq(6)
        when 3
          res[:block].index.should eq(4)
        when 4
          res[:block].index.should eq(2)
        when 5
          res[:block].index.should eq(0)
        end

        case res[:confirmations]
        when 0
          res[:block].index.should eq(10)
        when 1
          res[:block].index.should eq(8)
        when 2
          res[:block].index.should eq(6)
        when 3
          res[:block].index.should eq(4)
        when 4
          res[:block].index.should eq(2)
        when 5
          res[:block].index.should eq(0)
        end
      end
    end
  end

  it "it should get the number of confirmations for a transaction with mainly fast blocks" do
    with_factory do |block_factory, transaction_factory|
      block_factory.add_slow_blocks(1)
      sleep 0.001
      block_factory.add_fast_block([transaction_factory.make_fast_send(1)])
      sleep 0.001
      block_factory.add_fast_block([transaction_factory.make_fast_send(1)])
      sleep 0.001
      block_factory.add_fast_block([transaction_factory.make_fast_send(1)])
      sleep 0.001
      block_factory.add_fast_block([transaction_factory.make_fast_send(1)])
      sleep 0.001
      block_factory.add_fast_block([transaction_factory.make_fast_send(1)])

      block_factory.blockchain.wallet_info.wallet_info_impl(block_factory.node_wallet.address).recent_transactions.each do |rt|
        block_info = block_factory.blockchain.blockchain_info.block_transaction_impl(false, rt.transaction_id)
        res = block_info.as(NamedTuple(block: Axentro::Core::Block, confirmations: Int32))

        case rt.confirmations.to_i
        when 0
          res[:block].index.should eq(9)
        when 1
          res[:block].index.should eq(7)
        when 2
          res[:block].index.should eq(5)
        when 3
          res[:block].index.should eq(3)
        when 4
          res[:block].index.should eq(1)
        when 5
          res[:block].index.should eq(2)
        when 6
          res[:block].index.should eq(0)
        end

        case res[:confirmations]
        when 0
          res[:block].index.should eq(9)
        when 1
          res[:block].index.should eq(7)
        when 2
          res[:block].index.should eq(5)
        when 3
          res[:block].index.should eq(3)
        when 4
          res[:block].index.should eq(1)
        when 5
          res[:block].index.should eq(2)
        when 6
          res[:block].index.should eq(0)
        end
      end
    end
  end

  it "it should get the number of confirmations for a transaction with mixture of slow and fast blocks" do
    with_factory do |block_factory, transaction_factory|
      block_factory.add_slow_blocks(1)
      block_factory.add_fast_block([transaction_factory.make_fast_send(1)])
      sleep 0.001
      block_factory.add_slow_blocks(1)
      block_factory.add_fast_block([transaction_factory.make_fast_send(1)])
      sleep 0.001
      block_factory.add_slow_block([transaction_factory.make_send(1)])
      block_factory.add_fast_block([transaction_factory.make_fast_send(1)])
      sleep 0.001
      block_factory.add_slow_blocks(1)
      block_factory.add_fast_block([transaction_factory.make_fast_send(1)])
      sleep 0.001
      block_factory.add_slow_blocks(1)
      block_factory.add_fast_block([transaction_factory.make_fast_send(1)])

      block_factory.blockchain.wallet_info.wallet_info_impl(block_factory.node_wallet.address).recent_transactions.each do |rt|
        block_info = block_factory.blockchain.blockchain_info.block_transaction_impl(false, rt.transaction_id)
        res = block_info.as(NamedTuple(block: Axentro::Core::Block, confirmations: Int32))

        case rt.confirmations.to_i
        when 0
          res[:block].index.should eq(9)
        when 1
          res[:block].index.should eq(10)
        when 2
          res[:block].index.should eq(7)
        when 3
          res[:block].index.should eq(8)
        when 4
          res[:block].index.should eq(5)
        when 5
          res[:block].index.should eq(6)
        when 6
          res[:block].index.should eq(3)
        when 7
          res[:block].index.should eq(4)
        when 8
          res[:block].index.should eq(1)
        when 9
          res[:block].index.should eq(2)
        when 10
          res[:block].index.should eq(0)
        end

        case res[:confirmations]
        when 0
          res[:block].index.should eq(9)
        when 1
          res[:block].index.should eq(10)
        when 2
          res[:block].index.should eq(7)
        when 3
          res[:block].index.should eq(8)
        when 4
          res[:block].index.should eq(5)
        when 5
          res[:block].index.should eq(6)
        when 6
          res[:block].index.should eq(3)
        when 7
          res[:block].index.should eq(4)
        when 8
          res[:block].index.should eq(1)
        when 9
          res[:block].index.should eq(2)
        when 10
          res[:block].index.should eq(0)
        end
      end
    end
  end
end
