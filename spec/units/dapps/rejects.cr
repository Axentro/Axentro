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

include Sushi::Core
include Units::Utils
include Sushi::Core::DApps::BuildIn
include Sushi::Core::Controllers

describe Rejects do
  it "should perform #setup" do
    with_factory do |block_factory, transaction_factory|
      chain = block_factory.addBlock.chain
      rejects = Rejects.new(blockchain_node(transaction_factory.sender_wallet))
      rejects.setup.should be_nil
    end
  end
  it "should perform #transaction_actions" do
    with_factory do |block_factory, transaction_factory|
      chain = block_factory.addBlock.chain
      rejects = Rejects.new(blockchain_node(transaction_factory.sender_wallet))
      rejects.transaction_actions.size.should eq(0)
    end
  end
  it "should perform #transaction_related?" do
    with_factory do |block_factory, transaction_factory|
      chain = block_factory.addBlock.chain
      rejects = Rejects.new(blockchain_node(transaction_factory.sender_wallet))
      rejects.transaction_related?("action").should be_false
    end
  end
  it "should perform #valid_transaction?" do
    with_factory do |block_factory, transaction_factory|
      chain = block_factory.addBlocks(2).chain
      rejects = Rejects.new(blockchain_node(transaction_factory.sender_wallet))
      rejects.valid_transaction?(chain.last.transactions.first, chain.last.transactions).should be_true
    end
  end
  it "should perform #record" do
    with_factory do |block_factory, transaction_factory|
      chain = block_factory.addBlocks(2).chain
      rejects = Rejects.new(blockchain_node(transaction_factory.sender_wallet))
      rejects.record(chain).should be_nil
    end
  end

  describe "record_reject" do
    it "should record a rejected transaction with exception message" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(2).chain
        transaction_id = chain.last.transactions.last.id
        rejects = Rejects.new(blockchain_node(transaction_factory.sender_wallet))
        rejects.record_reject(transaction_id, Exception.new("oops"))
        rejects.@rejects.should eq({transaction_id => "oops"})
      end
    end
    it "should record a rejected transaction with default exception message" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(2).chain
        transaction_id = chain.last.transactions.last.id
        rejects = Rejects.new(blockchain_node(transaction_factory.sender_wallet))
        rejects.record_reject(transaction_id, Exception.new)
        rejects.@rejects.should eq({transaction_id => "unknown"})
      end
    end
  end
  it "should perform #clear" do
    with_factory do |block_factory, transaction_factory|
      chain = block_factory.addBlocks(2).chain
      rejects = Rejects.new(blockchain_node(transaction_factory.sender_wallet))
      rejects.record_reject(chain.last.transactions.last.id, Exception.new)
      rejects.clear
      rejects.@rejects.size.should eq(0)
    end
  end

  describe "#define_rpc?" do
    describe "#rejects" do
      it "should return a reject true with a reason for the supplied transaction id" do
        with_factory do |block_factory, transaction_factory|
          transaction = transaction_factory.make_send(1000000000_i64)
          block_factory.addBlocks(1).addBlock([transaction])

          payload = {call: "rejects", transaction_id: transaction.id}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            result.should eq("{\"rejected\":true,\"reason\":\"sender has not enough token(SHARI). sender has 20000 + 0 but try to pay 1000000000\"}")
          end
        end
      end

      it "should return a reject false for the supplied transaction id" do
        with_factory do |block_factory, transaction_factory|
          transaction = transaction_factory.make_send(1_i64)
          block_factory.addBlock([transaction])

          payload = {call: "rejects", transaction_id: transaction.id}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            result.should eq("{\"rejected\":false,\"reason\":\"\"}")
          end
        end
      end

      it "should return a reject false when transaction not found" do
        with_factory do |block_factory, transaction_factory|
          payload = {call: "rejects", transaction_id: "invalid-transaction-id"}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            result.should eq("{\"rejected\":false,\"reason\":\"\"}")
          end
        end
      end
    end
  end
  STDERR.puts "< dApps::Rejects"
end
