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
include Axentro::Core::DApps::BuildIn
include Axentro::Core::Controllers

describe OfficialNode do
  describe "default non implemented methods" do
    it "should perform #setup" do
      with_factory do |block_factory, _|
        transaction_creator = OfficialNode.new(block_factory.add_slow_block.blockchain)
        transaction_creator.setup.should be_nil
      end
    end
    it "should perform #transaction_actions" do
      with_factory do |block_factory, _|
        transaction_creator = OfficialNode.new(block_factory.add_slow_block.blockchain)
        transaction_creator.transaction_actions.should eq(["create_official_node_slow", "create_official_node_fast"])
      end
    end
    it "should perform #transaction_related?" do
      with_factory do |block_factory, _|
        transaction_creator = OfficialNode.new(block_factory.add_slow_block.blockchain)
        transaction_creator.transaction_related?("create_official_node_slow").should be_true
        transaction_creator.transaction_related?("create_official_node_fast").should be_true
      end
    end
    it "should reject any offical node transactions when #valid_transactions?" do
      with_factory do |block_factory, tf|
        transaction_creator = OfficialNode.new(block_factory.blockchain)
        valid_txn = tf.make_send(100)
        invalid_txns = [tf.make_create_offical_slownode, tf.make_create_offical_fastnode]
        result = transaction_creator.valid_transactions?([valid_txn] + invalid_txns)
        result.failed.size.should eq(2)
        result.passed.size.should eq(1)
        result.passed.first.should eq(valid_txn)
      end
    end
    it "should perform #record" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(2).chain
        transaction_creator = OfficialNode.new(block_factory.blockchain)
        transaction_creator.record(chain).should be_nil
      end
    end
    it "should perform #clear" do
      with_factory do |block_factory, _|
        transaction_creator = OfficialNode.new(block_factory.add_slow_blocks(2).blockchain)
        transaction_creator.clear.should be_nil
      end
    end
  end

  describe "official nodes impl" do
    slownodes = ["VDAyNThiOWFiN2Q5YWM3ZjUyYTNhYzQwZTY1NDBmYWJkMjczZmVmZThlOTgzMWM4", "VDA4M2YwYTkzZTQxZTQ0NzdjOGRjMDU4ZTkwZTI4OWY1NDNkMDZjYmU3ODQyM2Rk"]
    fastnodes = ["VDAwZDRiYTg0MWVlZjE4M2U3OWY2N2E0YmZkZDJjN2JmMWE0ZTViMjE3ZDNmZTU1"]
    official_nodes = OfficialNodes.new({"slownodes" => slownodes, "fastnodes" => fastnodes})

    it "should return all nodes for" do
      with_factory(nil, false, official_nodes) do |block_factory, _|
        transaction_creator = OfficialNode.new(block_factory.blockchain)
        transaction_creator.all_impl.should eq(slownodes + fastnodes)
      end
    end
    it "should return all slow nodes for" do
      with_factory(nil, false, official_nodes) do |block_factory, _|
        transaction_creator = OfficialNode.new(block_factory.blockchain)
        transaction_creator.all_slow_impl.should eq(slownodes)
      end
    end

    it "should return all fast nodes for" do
      with_factory(nil, false, official_nodes) do |block_factory, _|
        transaction_creator = OfficialNode.new(block_factory.blockchain)
        transaction_creator.all_fast_impl.should eq(fastnodes)
      end
    end
  end
end
