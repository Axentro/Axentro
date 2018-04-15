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

describe Fees do
  describe "default non implemented methods" do
    it "should perform #setup" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        fees = Fees.new(blockchain_node(transaction_factory.sender_wallet))
        fees.setup.should be_nil
      end
    end
    it "should perform #transaction_actions" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        fees = Fees.new(blockchain_node(transaction_factory.sender_wallet))
        fees.transaction_actions.size.should eq(0)
      end
    end
    it "should perform #transaction_related?" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        fees = Fees.new(blockchain_node(transaction_factory.sender_wallet))
        fees.transaction_related?("action").should be_false
      end
    end
    it "should perform #valid_transaction?" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(2).chain
        fees = Fees.new(blockchain_node(transaction_factory.sender_wallet))
        fees.valid_transaction?(chain.last.transactions.first, chain.last.transactions).should be_true
      end
    end
    it "should perform #record" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(2).chain
        fees = Fees.new(blockchain_node(transaction_factory.sender_wallet))
        fees.record(chain).should be_nil
      end
    end
    it "should perform #clear" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(2).chain
        fees = Fees.new(blockchain_node(transaction_factory.sender_wallet))
        fees.clear.should be_nil
      end
    end
  end

  describe "#define_rpc?" do
    describe "#fees" do
      it "should return the fees" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "fees"}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |result|
            result.should eq("{\"send\":1,\"scars_buy\":100,\"scars_sell\":10,\"scars_cancel\":1,\"create_token\":1000}")
          end
        end
      end
    end
  end
  STDERR.puts "< dApps::Fees"
end
