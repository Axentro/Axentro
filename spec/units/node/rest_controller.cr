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

  describe "__v1_transaction_id" do
    it "should return the transaction for the specified transaction id" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        block_factory.addBlock([transaction]).addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id(context("/api/v1/transaction/#{transaction.id}"), {id: transaction.id})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["status"].to_s.should eq("accepted")
          Transaction.from_json(result["result"]["transaction"].to_json)
        end
      end
    end
    it "should return not found when specified transaction is not found" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id(context("/api/v1/transaction/non-existing-txn-id"), {id: "non-existing-txn-id"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["status"].should eq("not found")
        end
      end
    end
  end

  describe "__v1_transaction_id_block" do
    it "should return the block containing the specified transaction id" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        block_factory.addBlock([transaction]).addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id_block(context("/api/v1/transaction/#{transaction.id}/block"), {id: transaction.id})) do |result|
          result["status"].to_s.should eq("success")
          Block.from_json(result["result"].to_json)
        end
      end
    end
    it "should return not found when transaction is not found" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id_block(context("/api/v1/transaction/non-existing-txn-id/block"), {id: "non-existing-txn-id"})) do |result|
          result["status"].to_s.should eq("error")
          result["reason"].should eq("failed to find a block for the transaction non-existing-txn-id")
        end
      end
    end
  end

  describe "__v1_transaction_id_block_header" do
    it "should return the block header containing the specified transaction id" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        block_factory.addBlock([transaction]).addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id_block_header(context("/api/v1/transaction/#{transaction.id}/block/header"), {id: transaction.id})) do |result|
          result["status"].to_s.should eq("success")
          Blockchain::Header.from_json(result["result"].to_json)
        end
      end
    end
    it "should return not found when transaction is not found" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id_block_header(context("/api/v1/transaction/non-existing-txn-id/block/header"), {id: "non-existing-txn-id"})) do |result|
          result["status"].to_s.should eq("error")
          result["reason"].should eq("failed to find a block for the transaction non-existing-txn-id")
        end
      end
    end
  end

  describe "__v1_transaction_id_confirmations" do
    it "should return the confirmations for the specified transaction id" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        block_factory.addBlock([transaction]).addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id_confirmations(context("/api/v1/transaction/#{transaction.id}/confirmations"), {id: transaction.id})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmations"].should eq(3_i64)
        end
      end
    end
    it "should return not found when transaction is not found" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id_confirmations(context("/api/v1/transaction/non-existing-txn-id/confirmations"), {id: "non-existing-txn-id"})) do |result|
          result["status"].to_s.should eq("error")
          result["reason"].should eq("failed to find a block for the transaction non-existing-txn-id")
        end
      end
    end
  end

  describe "__v1_transaction_fees" do
    it "should return the transaction fees" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_fees(context("/api/v1/transaction/fees"), no_params)) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["send"].should eq("0.0001")
          result["result"]["scars_buy"].should eq("0.001")
          result["result"]["scars_sell"].should eq("0.0001")
          result["result"]["scars_cancel"].should eq("0.0001")
          result["result"]["create_token"].should eq("0.1")
        end
      end
    end
  end

  describe "__v1_address" do
    it "should return the amounts for the specified address" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        address = transaction_factory.sender_wallet.address
        exec_rest_api(block_factory.rest.__v1_address(context("/api/v1/address/#{address}"), {address: address})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(1_i64)
          result["result"]["pairs"][0].to_s.should eq("{\"token\" => \"SUSHI\", \"amount\" => \"1.009253\"}")
        end
      end
    end
    it "should return zero amount when address is not found" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_address(context("/api/v1/address/non-existing-address"), {address: "non-existing-address"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(1_i64)
          result["result"]["pairs"][0].to_s.should eq("{\"token\" => \"SUSHI\", \"amount\" => \"0\"}")
        end
      end
    end
  end

  describe "__v1_address_token" do
    it "should return the amounts for the specified address and token" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        address = transaction_factory.sender_wallet.address
        exec_rest_api(block_factory.rest.__v1_address_token(context("/api/v1/address/#{address}/token/SUSHI"), {address: address, token: "SUSHI"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(1_i64)
          result["result"]["pairs"][0].to_s.should eq("{\"token\" => \"SUSHI\", \"amount\" => \"1.009253\"}")
        end
      end
    end
    it "should return no pairs when address and token is not found" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_address_token(context("/api/v1/address/non-existing-address/token/NONE"), {address: "non-existing-address", token: "NONE"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(1_i64)
          result["result"]["pairs"].to_s.should eq("[]")
        end
      end
    end
  end

  describe "__v1_address_transactions" do
    it "should return all transactions for the specified address" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        transaction = transaction_factory.make_send(100_i64)
        block_factory.addBlock([transaction]).addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/#{address}/transactions"), {address: address})) do |result|
          result["status"].to_s.should eq("success")
          Array(Transaction).from_json(result["result"].to_json)
        end
      end
    end
    it "should return filtered transactions for the specified address" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        transaction = transaction_factory.make_send(100_i64)
        block_factory.addBlock([transaction]).addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/#{address}/transactions?actions=send"), {address: address, actions: "send"})) do |result|
          result["status"].to_s.should eq("success")
          transactions = Array(Transaction).from_json(result["result"].to_json)
          transactions.map { |txn| txn.action }.uniq.should eq(["send"])
        end
      end
    end
    it "should return empty list for filtered transactions for the specified address" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        transaction = transaction_factory.make_send(100_i64)
        block_factory.addBlock([transaction]).addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/#{address}/transactions?actions=unknown"), {address: address, actions: "unknown"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"].to_s.should eq("[]")
        end
      end
    end
    it "should return empty result when specified address and filter is not found" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        transaction = transaction_factory.make_send(100_i64)
        block_factory.addBlock([transaction]).addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/no-address/transactions?actions=unknown"), {address: "no-address", actions: "unknown"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"].to_s.should eq("[]")
        end
      end
    end
    it "should paginate default 20 transactions for the specified address" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        block_factory.addBlocks(100)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/#{address}/transactions"), {address: address})) do |result|
          result["status"].to_s.should eq("success")
          transactions = Array(Transaction).from_json(result["result"].to_json)
          transactions.size.should eq(20)
        end
      end
    end
    it "should paginate transactions for the specified address" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        block_factory.addBlocks(200)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/#{address}/transactions?page_size=50&page=2"), {address: address, page_size: 50, page: 1})) do |result|
          result["status"].to_s.should eq("success")
          transactions = Array(Transaction).from_json(result["result"].to_json)
          transactions.size.should eq(50)
        end
      end
    end
  end

  describe "__v1_domain" do
    it "should return the amounts for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        domain = "sushi.sc"
        block_factory.addBlock([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_domain(context("/api/v1/domain/#{domain}"), {domain: domain})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(1_i64)
          result["result"]["pairs"][0].to_s.should eq("{\"token\" => \"SUSHI\", \"amount\" => \"1.3138795\"}")
        end
      end
    end
    it "should return error amount when domain is not found" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_domain(context("/api/v1/domain/non-existing-domain"), {domain: "non-existing-domain"})) do |result|
          result["status"].to_s.should eq("error")
          result["reason"].should eq("the domain non-existing-domain is not resolved")
        end
      end
    end
  end

  describe "__v1_domain_token" do
    it "should return the amounts for the specified domain and token" do
      with_factory do |block_factory, transaction_factory|
        domain = "sushi.sc"
        block_factory.addBlock([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_domain_token(context("/api/v1/domain/#{domain}/token/SUSHI"), {domain: domain, token: "SUSHI"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(1_i64)
          result["result"]["pairs"][0].to_s.should eq("{\"token\" => \"SUSHI\", \"amount\" => \"1.3138795\"}")
        end
      end
    end
    it "should return no pairs when token is not found" do
      with_factory do |block_factory, transaction_factory|
        domain = "sushi.sc"
        block_factory.addBlock([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_domain_token(context("/api/v1/address/#{domain}/token/NONE"), {domain: domain, token: "NONE"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(1_i64)
          result["result"]["pairs"].to_s.should eq("[]")
        end
      end
    end
  end

  describe "__v1_domain_transactions" do
    it "should return all transactions for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        domain = "sushi.sc"
        block_factory.addBlock([transaction, transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_domain_transactions(context("/api/v1/domain/#{domain}/transactions"), {domain: domain})) do |result|
          result["status"].to_s.should eq("success")
          Array(Transaction).from_json(result["result"].to_json)
        end
      end
    end
    it "should return filtered transactions for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        domain = "sushi.sc"
        block_factory.addBlock([transaction, transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_domain_transactions(context("/api/v1/domain/#{domain}/transactions?actions=send"), {domain: domain, actions: "send"})) do |result|
          result["status"].to_s.should eq("success")
          transactions = Array(Transaction).from_json(result["result"].to_json)
          transactions.map { |txn| txn.action }.uniq.should eq(["send"])
        end
      end
    end
    it "should return empty list for filtered transactions for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        domain = "sushi.sc"
        block_factory.addBlock([transaction, transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_domain_transactions(context("/api/v1/domain/#{domain}/transactions?actions=unknown"), {domain: domain, actions: "unknown"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"].to_s.should eq("[]")
        end
      end
    end
    it "should paginate default 20 transactions for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        domain = "sushi.sc"
        block_factory.addBlock([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).addBlocks(100)
        exec_rest_api(block_factory.rest.__v1_domain_transactions(context("/api/v1/domain/#{domain}/transactions"), {domain: domain})) do |result|
          result["status"].to_s.should eq("success")
          transactions = Array(Transaction).from_json(result["result"].to_json)
          transactions.size.should eq(20)
        end
      end
    end
    it "should paginate transactions for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        domain = "sushi.sc"
        block_factory.addBlock([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).addBlocks(200)
        exec_rest_api(block_factory.rest.__v1_domain_transactions(context("/api/v1/domain/#{domain}/transactions?page_size=50&page=2"), {domain: domain, page_size: 50, page: 1})) do |result|
          result["status"].to_s.should eq("success")
          transactions = Array(Transaction).from_json(result["result"].to_json)
          transactions.size.should eq(50)
        end
      end
    end
  end

  STDERR.puts "< Node::RESTController"
end

def context(url : String)
  MockContext.new("GET", url).unsafe_as(HTTP::Server::Context)
end

def no_params
  {} of String => String
end
