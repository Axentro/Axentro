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
include Axentro::Core::Controllers
include Axentro::Core::Keys

describe "Chunked Sync" do
  describe "should create a list of ids for the subchain" do
    it "when empty db" do
      with_factory do |block_factory, _|
        node = block_factory.node
        slow_index = 0_i64
        fast_index = 0_i64
        count = 5
        node.subchain_algo(slow_index, fast_index, count).map(&.index).should eq([0])
      end
    end

    it "when all slow blocks and indexes 0,0" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(20)
        node = block_factory.node
        slow_index = 0_i64
        fast_index = 0_i64
        count = 5
        node.subchain_algo(slow_index, fast_index, count).map(&.index).should eq([0, 2, 4, 6, 8])
      end
    end

    it "when all fast blocks and indexes 0,0" do
      with_factory do |block_factory, _|
        block_factory.add_fast_blocks(20)
        node = block_factory.node
        slow_index = 0_i64
        fast_index = 0_i64
        count = 5
        node.subchain_algo(slow_index, fast_index, count).map(&.index).should eq([0, 1, 3, 5, 7])
      end
    end

    it "when slow blocks then fast and indexes 0,0" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(20)
        sleep 0.001
        block_factory.add_fast_blocks(20)
        node = block_factory.node
        slow_index = 0_i64
        fast_index = 0_i64
        count = 5
        node.subchain_algo(slow_index, fast_index, count).map(&.index).should eq([0, 2, 4, 6, 8])
      end
    end

    it "when mixed slow blocks and fast and indexes 0,0" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        sleep 0.001
        block_factory.add_fast_blocks(2)
        sleep 0.001
        block_factory.add_slow_blocks(2)
        sleep 0.001
        block_factory.add_fast_blocks(2)
        node = block_factory.node
        slow_index = 0_i64
        fast_index = 0_i64
        count = 5
        node.subchain_algo(slow_index, fast_index, count).map(&.index).should eq([0, 2, 4, 1, 3])
      end
    end

    it "when mixed slow blocks and fast and indexes 4,0" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        sleep 0.001
        block_factory.add_fast_blocks(2)
        sleep 0.001
        block_factory.add_slow_blocks(2)
        sleep 0.001
        block_factory.add_fast_blocks(2)
        node = block_factory.node
        slow_index = 4_i64
        fast_index = 0_i64
        count = 5
        node.subchain_algo(slow_index, fast_index, count).map(&.index).should eq([1, 3, 6, 8, 5])
      end
    end

    it "when mixed slow blocks and fast and indexes 4,0" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        sleep 0.001
        block_factory.add_fast_blocks(2)
        sleep 0.001
        block_factory.add_slow_blocks(2)
        sleep 0.001
        block_factory.add_fast_blocks(2)
        node = block_factory.node
        slow_index = 4_i64
        fast_index = 1_i64
        count = 5
        node.subchain_algo(slow_index, fast_index, count).map(&.index).should eq([3, 6, 8, 5, 7])
      end
    end

    it "when mixed slow blocks and fast and indexes 2,5" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        sleep 0.001
        block_factory.add_fast_blocks(2)
        sleep 0.001
        block_factory.add_slow_blocks(2)
        sleep 0.001
        block_factory.add_fast_blocks(2)
        node = block_factory.node
        slow_index = 2_i64
        fast_index = 5_i64
        count = 5
        node.subchain_algo(slow_index, fast_index, count).map(&.index).should eq([4, 6, 8, 7])
      end
    end
  end

  describe "validation on sync - check the % of incoming blocks according to the configured security percentage (20% default)" do
    it "on incoming chain" do
      incoming_chain = [] of (SlowBlock | FastBlock)
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(40)
        sleep 0.001
        block_factory.add_fast_blocks(40)
        sleep 0.001
        block_factory.add_slow_blocks(20)
        incoming_chain = block_factory.chain
      end

      with_factory do |block_factory, _|
        block_factory.blockchain.create_indexes_to_check(incoming_chain).size.should eq(24)
      end
    end
  end
end
