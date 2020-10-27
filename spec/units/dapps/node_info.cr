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

describe NodeInfo do
  describe "default non implemented methods" do
    it "should perform #setup" do
      with_factory do |block_factory, _|
        transaction_creator = NodeInfo.new(block_factory.add_slow_block.blockchain)
        transaction_creator.setup.should be_nil
      end
    end
    it "should perform #transaction_actions" do
      with_factory do |block_factory, _|
        transaction_creator = NodeInfo.new(block_factory.add_slow_block.blockchain)
        transaction_creator.transaction_actions.size.should eq(0)
      end
    end
    it "should perform #transaction_related?" do
      with_factory do |block_factory, _|
        transaction_creator = NodeInfo.new(block_factory.add_slow_block.blockchain)
        transaction_creator.transaction_related?("action").should be_false
      end
    end
    # it "should perform #valid_transaction?" do
    #   with_factory do |block_factory, _|
    #     chain = block_factory.add_slow_blocks(2).chain
    #     transaction_creator = NodeInfo.new(block_factory.blockchain)
    #     transaction_creator.valid_transaction?(chain.last.transactions.first, chain.last.transactions).should be_true
    #   end
    # end
    it "should perform #record" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(2).chain
        transaction_creator = NodeInfo.new(block_factory.blockchain)
        transaction_creator.record(chain).should be_nil
      end
    end
    it "should perform #clear" do
      with_factory do |block_factory, _|
        transaction_creator = NodeInfo.new(block_factory.add_slow_blocks(2).blockchain)
        transaction_creator.clear.should be_nil
      end
    end
  end

  describe "#nodes" do
    it "should return the nodes on the network" do
      with_factory do |block_factory, _|
        payload = {call: "nodes"}.to_json
        json = JSON.parse(payload)

        with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
          result.should eq("{\"successor_list\":[],\"predecessor\":null,\"private_nodes\":[],\"finger_table\":[]}")
        end
      end
    end
  end

  describe "#node" do
    it "should return the node on the network" do
      with_factory do |block_factory, _|
        payload = {call: "node"}.to_json
        json = JSON.parse(payload)

        node_id = block_factory.node.chord.context[:id]
        with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
          result.should eq("{\"id\":\"#{node_id}\",\"host\":\"\",\"port\":-1,\"ssl\":false,\"type\":\"testnet\",\"is_private\":true,\"address\":\"\"}")
        end
      end
    end
  end

  describe "#node_id" do
    it "should return the node on the network" do
      with_factory do |block_factory, _|
        node_id = block_factory.node.chord.context[:id]
        payload = {call: "node_id", id: node_id}.to_json
        json = JSON.parse(payload)

        node_id = block_factory.node.chord.context[:id]
        with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
          result.should eq("{\"id\":\"#{node_id}\",\"host\":\"\",\"port\":-1,\"ssl\":false,\"type\":\"testnet\",\"is_private\":true,\"address\":\"\"}")
        end
      end
    end
  end

  describe "#node_id" do
    it "should return the node on the network" do
      with_factory do |block_factory, _|
        node_id = block_factory.node.chord.context[:id]
        payload = {call: "node_address", address: ""}.to_json
        json = JSON.parse(payload)

        node_id = block_factory.node.chord.context[:id]
        with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
          result.should eq("[{\"id\":\"#{node_id}\",\"host\":\"\",\"port\":-1,\"ssl\":false,\"type\":\"testnet\",\"is_private\":true,\"address\":\"\"}]")
        end
      end
    end
  end

  describe "#official_nodes" do
    it "should return the node on the network" do
      with_factory do |block_factory, _|
        payload = {call: "official_nodes"}.to_json
        json = JSON.parse(payload)

        with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
          result.should eq("{\"all\":[\"#{block_factory.node_wallet.address}\"],\"online\":[]}")
        end
      end
    end
  end
end
