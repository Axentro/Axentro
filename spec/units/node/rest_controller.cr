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
include Sushi::Core::Controllers
include Sushi::Core::Keys

describe RESTController do

  describe "__v1_blockchain" do
    it "should return the full blockchain" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_blockchain(context("/api/v1/blockchain"), no_params)) do |result|
           result["status"].to_s.should eq("success")
           Array(Block).from_json(result["result"].to_json).size.should eq(3)
        end
      end
    end
  end

  describe "__v1_blockchain_header" do
    it "should return the only blockchain headers" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_blockchain_header(context("/api/v1/blockchain/header"), no_params)) do |result|
           result["status"].to_s.should eq("success")
           Array(Blockchain::Header).from_json(result["result"].to_json).size.should eq(3)
        end
      end
    end
  end

  describe "__v1_blockchain_size" do
    it "should return the full blockchain size" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_blockchain_size(context("/api/v1/blockchain/size"), no_params)) do |result|
           result["status"].to_s.should eq("success")
           result["result"]["size"].should eq(3)
        end
      end
    end
  end

  describe "__v1_block_index" do
    it "should return the block for the specified index" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index(context("/api/v1/block"), {index: 0})) do |result|
           result["status"].to_s.should eq("success")
           Block.from_json(result["result"].to_json)
        end
      end
    end
    it "should failure when block index is invalid" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index(context("/api/v1/block/99"), {index: 99})) do |result|
           result["status"].to_s.should eq("error")
           result["reason"].should eq("invalid index 99 (blockchain size is 3)")
        end
      end
    end
  end

  describe "__v1_block_index_header" do
    it "should return the block header for the specified index" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index_header(context("/api/v1/block/0/header"), {index: 0})) do |result|
           result["status"].to_s.should eq("success")
           Blockchain::Header.from_json(result["result"].to_json)
        end
      end
    end
    it "should return failure when block index is invalid" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index_header(context("/api/v1/block/99/header"), {index: 99})) do |result|
           result["status"].to_s.should eq("error")
           result["reason"].should eq("invalid index 99 (blockchain size is 3)")
        end
      end
    end
  end

  describe "__v1_block_index_transactions" do
    it "should return the block transactions for the specified index" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index_transactions(context("/api/v1/block/0/header"), {index: 0})) do |result|
           result["status"].to_s.should eq("success")
           Array(Transaction).from_json(result["result"].to_json)
        end
      end
    end
    it "should return failure when block index is invalid" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index_transactions(context("/api/v1/block/99/header"), {index: 99})) do |result|
           result["status"].to_s.should eq("error")
           result["reason"].should eq("invalid index 99 (blockchain size is 3)")
        end
      end
    end
  end

  # describe "__v1_transaction_id" do
  #   it "should return the transaction for the specified transaction id" do
  #     with_factory do |block_factory, transaction_factory|
  #       block_factory.addBlocks(2)
  #       exec_rest_api(block_factory.rest.__v1_block_index_transactions(context("/api/v1/block/0/header"), {index: 0})) do |result|
  #          result["status"].to_s.should eq("success")
  #          Array(Transaction).from_json(result["result"].to_json)
  #       end
  #     end
  #   end
  #   it "should return failure when block index is invalid" do
  #     with_factory do |block_factory, transaction_factory|
  #       block_factory.addBlocks(2)
  #       exec_rest_api(block_factory.rest.__v1_block_index_transactions(context("/api/v1/block/99/header"), {index: 99})) do |result|
  #          result["status"].to_s.should eq("error")
  #          result["reason"].should eq("invalid index 99 (blockchain size is 3)")
  #       end
  #     end
  #   end
  # end


end



def context(url : String)
  MockContext.new("GET", url).unsafe_as(HTTP::Server::Context)
end

def no_params
 {} of String => String
end
