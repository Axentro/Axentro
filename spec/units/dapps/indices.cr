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

include Sushi::Core::Models
include Sushi::Core
include Units::Utils
include Sushi::Core::DApps::BuildIn
include Sushi::Core::Controllers

describe Indices do
  it "should perform #setup" do
    with_factory do |block_factory, transaction_factory|
      chain = block_factory.addBlock.chain
      indices = Indices.new(blockchain_node(transaction_factory.sender_wallet))
      indices.setup.should be_nil
    end
  end

  describe "#get" do
    it "should return the indice for the given transaction" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(2).chain
        indices = Indices.new(blockchain_node(transaction_factory.sender_wallet))
        indices.record(chain)
        indices.get(chain.last.transactions.last.id).should eq(2)
      end
    end
    it "should return nil if the transaction is not found in the chain" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(2).chain
        indices = Indices.new(blockchain_node(transaction_factory.sender_wallet))
        indices.record(chain)
        indices.get("non-existing-transaction-id").should be_nil
      end
    end
  end

  it "should perform #transaction_actions" do
    with_factory do |block_factory, transaction_factory|
      chain = block_factory.addBlock.chain
      indices = Indices.new(blockchain_node(transaction_factory.sender_wallet))
      indices.transaction_actions.size.should eq(0)
    end
  end
  it "should perform #transaction_related?" do
    with_factory do |block_factory, transaction_factory|
      chain = block_factory.addBlock.chain
      indices = Indices.new(blockchain_node(transaction_factory.sender_wallet))
      indices.transaction_related?("action").should be_false
    end
  end
  it "should perform #valid_transaction?" do
    with_factory do |block_factory, transaction_factory|
      chain = block_factory.addBlocks(2).chain
      indices = Indices.new(blockchain_node(transaction_factory.sender_wallet))
      indices.valid_transaction?(chain.last.transactions.first, chain.last.transactions).should be_true
    end
  end
  it "should perform #record" do
    with_factory do |block_factory, transaction_factory|
      chain = block_factory.addBlocks(2).chain
      indices = Indices.new(blockchain_node(transaction_factory.sender_wallet))
      indices.record(chain)
      indices.@indices.reject(&.empty?).size.should eq(2)
    end
  end
  it "should perform #clear" do
    with_factory do |block_factory, transaction_factory|
      chain = block_factory.addBlocks(2).chain
      indices = Indices.new(blockchain_node(transaction_factory.sender_wallet))
      indices.record(chain)
      indices.clear
      indices.@indices.size.should eq(0)
    end
  end

  describe "#define_rpc?" do
    describe "#transaction" do
      it "should return a transaction for the supplied transaction id" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          transaction = chain[2].transactions.first
          payload = {call: "transaction", transaction_id: transaction.id}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |result|
            result.should eq("{\"found\":true,\"transaction\":#{transaction.to_json}}")
          end
        end
      end

      it "should return transaction not found in any block" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "transaction", transaction_id: "invalid-transaction-id"}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |result|
            result.should eq("{\"found\":false}")
          end
        end
      end
    end

    describe "#confirmation" do
      it "should return confirmation info for the supplied transaction id" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "confirmation", transaction_id: chain[2].transactions.first.id}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |result|
            json_result = JSON.parse(result)
            json_result["confirmed"].as_bool.should be_false
            json_result["confirmations"].as_i.should eq(8)
            json_result["threshold"].as_i.should eq(10)
          end
        end
      end
      it "should go go" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "confirmation", transaction_id: "non-existing-transaction-id"}.to_json
          json = JSON.parse(payload)

          expect_raises(Exception, "failed to find a block for the transaction non-existing-transaction-id") do
            with_rpc_exec_internal_post(rpc, json) { }
          end
        end
      end
    end
  end
  STDERR.puts "< dApps::Indices"
end
