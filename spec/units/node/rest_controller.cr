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

private def asset_blockchain(api_path)
  with_factory do |block_factory, _|
    block_factory.add_slow_blocks(50)
    exec_rest_api(block_factory.rest.__v1_blockchain(context(api_path), no_params)) do |result|
      result["status"].to_s.should eq("success")
      yield result["result"]
    end
  end
end

private def asset_blockchain_header(api_path)
  with_factory do |block_factory, _|
    block_factory.add_slow_blocks(50)
    exec_rest_api(block_factory.rest.__v1_blockchain_header(context(api_path), no_params)) do |result|
      result["status"].to_s.should eq("success")
      yield result["result"]
    end
  end
end

describe RESTController do
  describe "__v1_blockchain" do
    it "should return the full blockchain with pagination defaults (page:0,per_page:20,direction:desc)" do
      asset_blockchain("/api/v1/blockchain") do |result|
        blocks = Array(SlowBlock).from_json(result.to_json)
        blocks.size.should eq(20)
        blocks.first.index.should eq(100)
      end
    end
    it "should return the full blockchain with pagination specified direction (page:0,per_page:20,direction:asc)" do
      asset_blockchain("/api/v1/blockchain?direction=up") do |result|
        blocks = Array(SlowBlock).from_json(result.to_json)
        blocks.size.should eq(20)
        blocks.first.index.should eq(0)
      end
    end
    it "should return the full blockchain with pagination specified direction (page:2,per_page:1,direction:desc)" do
      asset_blockchain("/api/v1/blockchain?page=2&per_page=1&direction=down") do |result|
        blocks = Array(SlowBlock).from_json(result.to_json)
        blocks.size.should eq(1)
        blocks.first.index.should eq(96)
      end
    end
  end

  describe "__v1_blockchain_header" do
    it "should return the blockchain headers with pagination defaults (page:0,per_page:20,direction:desc)" do
      asset_blockchain_header("/api/v1/blockchain/header") do |result|
        blocks = Array(Blockchain::SlowHeader).from_json(result.to_json)
        blocks.size.should eq(20)
        blocks.first[:index].should eq(100)
      end
    end
    it "should return the blockchain headers with pagination specified direction (page:0,per_page:20,direction:asc)" do
      asset_blockchain_header("/api/v1/blockchain/header/?direction=up") do |result|
        blocks = Array(Blockchain::SlowHeader).from_json(result.to_json)
        blocks.size.should eq(20)
        blocks.first[:index].should eq(0)
      end
    end
    it "should return the blockchain headers with pagination specified direction (page:2,per_page:1,direction:desc)" do
      asset_blockchain_header("/api/v1/blockchain/header?page=2&per_page=1&direction=down") do |result|
        blocks = Array(Blockchain::SlowHeader).from_json(result.to_json)
        blocks.size.should eq(1)
        blocks.first[:index].should eq(96)
      end
    end
  end

  describe "__v1_blockchain_size" do
    it "should return the full blockchain size when chain fits into memory" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_blockchain_size(context("/api/v1/blockchain/size"), no_params)) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["totals"]["total_size"].should eq(3)
          result["result"]["totals"]["total_fast"].should eq(0)
          result["result"]["totals"]["total_slow"].should eq(3)
          result["result"]["block_height"]["fast"].should eq(-1)
          result["result"]["block_height"]["slow"].should eq(4)
        end
      end
    end
    it "should return the full blockchain size when chain is bigger than memory" do
      with_factory do |block_factory, _|
        blocks_to_add = block_factory.blocks_to_hold + 8
        block_factory.add_slow_blocks(blocks_to_add)
        exec_rest_api(block_factory.rest.__v1_blockchain_size(context("/api/v1/blockchain/size"), no_params)) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["totals"]["total_size"].should eq(blocks_to_add + 1)
        end
      end
    end
  end

  describe "__v1_block_index" do
    it "should return the block for the specified index" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index(context("/api/v1/block"), {index: 0})) do |result|
          result["status"].to_s.should eq("success")
          SlowBlock.from_json(result["result"]["block"].to_json)
        end
      end
    end
    it "should failure when block index is invalid" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index(context("/api/v1/block/99"), {index: 99})) do |result|
          result["status"].to_s.should eq("error")
          result["reason"].should eq("failed to find a block for the index: 99")
        end
      end
    end
  end

  describe "__v1_block_index_header" do
    it "should return the block header for the specified index" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index_header(context("/api/v1/block/0/header"), {index: 0})) do |result|
          result["status"].to_s.should eq("success")
          Blockchain::SlowHeader.from_json(result["result"].to_json)
        end
      end
    end
    it "should return failure when block index is invalid" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index_header(context("/api/v1/block/99/header"), {index: 99})) do |result|
          result["status"].to_s.should eq("error")
          result["reason"].should eq("failed to find a block for the index: 99")
        end
      end
    end
  end

  describe "__v1_block_index_transactions" do
    it "should return the block transactions for the specified index" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_block_index_transactions(context("/api/v1/block/0/header"), {index: 2})) do |result|
          result["status"].to_s.should eq("success")
          Array(Transaction).from_json(result["result"]["transactions"].to_json)
          result["result"]["confirmations"].as_i.should eq(2)
        end
      end
    end
  end

  describe "__v1_transaction_id" do
    it "should return the transaction for the specified transaction id" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id(context("/api/v1/transaction/#{transaction.id}"), {id: transaction.id})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["status"].to_s.should eq("accepted")
          Transaction.from_json(result["result"]["transaction"].to_json)
        end
      end
    end
    it "should return not found when specified transaction is not found" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
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
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id_block(context("/api/v1/transaction/#{transaction.id}/block"), {id: transaction.id})) do |result|
          result["status"].to_s.should eq("success")
          SlowBlock.from_json(result["result"]["block"].to_json)
        end
      end
    end
    it "should return not found when transaction is not found" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
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
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id_block_header(context("/api/v1/transaction/#{transaction.id}/block/header"), {id: transaction.id})) do |result|
          result["status"].to_s.should eq("success")
          Blockchain::SlowHeader.from_json(result["result"].to_json)
        end
      end
    end
    it "should return not found when transaction is not found" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_id_block_header(context("/api/v1/transaction/non-existing-txn-id/block/header"), {id: "non-existing-txn-id"})) do |result|
          result["status"].to_s.should eq("error")
          result["reason"].should eq("failed to find a block for the transaction non-existing-txn-id")
        end
      end
    end
  end

  describe "__v1_transaction_fees" do
    it "should return the transaction fees" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_transaction_fees(context("/api/v1/transaction/fees"), no_params)) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["send"].should eq("0.0001")
          result["result"]["hra_buy"].should eq("0.001")
          result["result"]["hra_sell"].should eq("0.0001")
          result["result"]["hra_cancel"].should eq("0.0001")
          result["result"]["create_token"].should eq("10")
        end
      end
    end
  end

  describe "__v1_address" do
    it "should return the amounts for the specified address" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(2)
        address = transaction_factory.sender_wallet.address
        exec_rest_api(block_factory.rest.__v1_address(context("/api/v1/address/#{address}"), {address: address})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(0_i64)
          result["result"]["pairs"][0].to_s.should eq("{\"token\" => \"AXNT\", \"amount\" => \"23.9999812\"}")
        end
      end
    end
    it "should return zero amount when address is not found" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_address(context("/api/v1/address/non-existing-address"), {address: "non-existing-address"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(0_i64)
          result["result"]["pairs"][0].to_s.should eq("{\"token\" => \"AXNT\", \"amount\" => \"0\"}")
        end
      end
    end
  end

  describe "__v1_address_token" do
    it "should return the amounts for the specified address and token" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(2)
        address = transaction_factory.sender_wallet.address
        exec_rest_api(block_factory.rest.__v1_address_token(context("/api/v1/address/#{address}/token/AXNT"), {address: address, token: "AXNT"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(0_i64)
          result["result"]["pairs"][0].to_s.should eq("{\"token\" => \"AXNT\", \"amount\" => \"23.9999812\"}")
        end
      end
    end
    it "should return no pairs when address and token is not found" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_address_token(context("/api/v1/address/non-existing-address/token/NONE"), {address: "non-existing-address", token: "NONE"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(0_i64)
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
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/#{address}/transactions"), {address: address})) do |result|
          result["status"].to_s.should eq("success")
          data = result["result"].as_a.map{|t| t["transaction"] }.to_json
          Array(Transaction).from_json(data)
        end
      end
    end
    it "should return filtered transactions for the specified address" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        transaction = transaction_factory.make_send(100_i64)
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/#{address}/transactions?actions=send"), {address: address, actions: "send"})) do |result|
          result["status"].to_s.should eq("success")
          data = result["result"].as_a.map{|t| t["transaction"] }.to_json
          transactions = Array(Transaction).from_json(data)
          transactions.map { |txn| txn.action }.uniq.should eq(["send"])
        end
      end
    end
    it "should return empty list for filtered transactions for the specified address" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        transaction = transaction_factory.make_send(100_i64)
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/#{address}/transactions?actions=unknown"), {address: address, actions: "unknown"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"].to_s.should eq("[]")
        end
      end
    end
    it "should return empty result when specified address and filter is not found" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        block_factory.add_slow_block([transaction]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/no-address/transactions?actions=unknown"), {address: "no-address", actions: "unknown"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"].to_s.should eq("[]")
        end
      end
    end
    it "should paginate default 20 transactions for the specified address" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        block_factory.add_slow_blocks(100)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/#{address}/transactions"), {address: address})) do |result|
          result["status"].to_s.should eq("success")
          data = result["result"].as_a.map{|t| t["transaction"] }.to_json
          transactions = Array(Transaction).from_json(data)
          transactions.size.should eq(20)
        end
      end
    end
    it "should paginate transactions for the specified address" do
      with_factory do |block_factory, transaction_factory|
        address = transaction_factory.sender_wallet.address
        block_factory.add_slow_blocks(200)
        exec_rest_api(block_factory.rest.__v1_address_transactions(context("/api/v1/address/#{address}/transactions?per_page=50&page=2"), {address: address, page_size: 50, page: 1})) do |result|
          result["status"].to_s.should eq("success")
          data = result["result"].as_a.map{|t| t["transaction"] }.to_json
          transactions = Array(Transaction).from_json(data)
          transactions.size.should eq(50)
        end
      end
    end
  end

  describe "__v1_domain" do
    it "should return the amounts for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_domain(context("/api/v1/domain/#{domain}"), {domain: domain})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(0_i64)
          result["result"]["pairs"][0].to_s.should eq("{\"token\" => \"AXNT\", \"amount\" => \"35.79996241\"}")
        end
      end
    end
    it "should return error amount when domain is not found" do
      with_factory do |block_factory, _|
        block_factory.add_slow_blocks(2)
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
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_domain_token(context("/api/v1/domain/#{domain}/token/AXNT"), {domain: domain, token: "AXNT"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(0_i64)
          result["result"]["pairs"][0].to_s.should eq("{\"token\" => \"AXNT\", \"amount\" => \"35.79996241\"}")
        end
      end
    end
    it "should return no pairs when token is not found" do
      with_factory do |block_factory, transaction_factory|
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_domain_token(context("/api/v1/address/#{domain}/token/NONE"), {domain: domain, token: "NONE"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["confirmation"].should eq(0_i64)
          result["result"]["pairs"].to_s.should eq("[]")
        end
      end
    end
  end

  describe "__v1_domain_transactions" do
    it "should return all transactions for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction, transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_domain_transactions(context("/api/v1/domain/#{domain}/transactions"), {domain: domain})) do |result|
          result["status"].to_s.should eq("success")
          data = result["result"].as_a.map{|t| t["transaction"] }.to_json
          Array(Transaction).from_json(data)
        end
      end
    end
    it "should return filtered transactions for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction, transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_domain_transactions(context("/api/v1/domain/#{domain}/transactions?actions=send"), {domain: domain, actions: "send"})) do |result|
          result["status"].to_s.should eq("success")
          data = result["result"].as_a.map{|t| t["transaction"] }.to_json
          transactions = Array(Transaction).from_json(data)
          transactions.map { |txn| txn.action }.uniq.should eq(["send"])
        end
      end
    end
    it "should return empty list for filtered transactions for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(100_i64)
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction, transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_domain_transactions(context("/api/v1/domain/#{domain}/transactions?actions=unknown"), {domain: domain, actions: "unknown"})) do |result|
          result["status"].to_s.should eq("success")
          result["result"].to_s.should eq("[]")
        end
      end
    end
    it "should paginate default 20 transactions for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(100)
        exec_rest_api(block_factory.rest.__v1_domain_transactions(context("/api/v1/domain/#{domain}/transactions"), {domain: domain})) do |result|
          result["status"].to_s.should eq("success")
          data = result["result"].as_a.map{|t| t["transaction"] }.to_json
          transactions = Array(Transaction).from_json(data)
          transactions.size.should eq(20)
        end
      end
    end
    it "should paginate transactions for the specified domain" do
      with_factory do |block_factory, transaction_factory|
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(200)
        exec_rest_api(block_factory.rest.__v1_domain_transactions(context("/api/v1/domain/#{domain}/transactions?per_page=50&page=2"), {domain: domain, page_size: 50, page: 1})) do |result|
          result["status"].to_s.should eq("success")  
          data = result["result"].as_a.map{|t| t["transaction"] }.to_json
          transactions = Array(Transaction).from_json(data)
          transactions.size.should eq(50)
        end
      end
    end
  end

  describe "__v1_hra_sales" do
    it "should return the domains for sale" do
      with_factory do |block_factory, transaction_factory|
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2).add_slow_block([transaction_factory.make_sell_domain(domain, 1_i64)]).add_slow_blocks(3)

        exec_rest_api(block_factory.rest.__v1_hra_sales(context("/api/v1/hra/sales"), no_params)) do |result|
          result["status"].to_s.should eq("success")
          result = Array(DomainResult).from_json(result["result"].to_json).first
          result.domain_name.should eq(domain)
          result.status.should eq(1_i64)
          result.price.should eq("0.00000001")
        end
      end
    end
  end

  describe "__v1_hra" do
    it "should return true when domain is resolved" do
      with_factory do |block_factory, transaction_factory|
        domain = "axentro.ax"
        block_factory.add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_hra(context("/api/v1/hra/#{domain}"), {domain: domain})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["resolved"].to_s.should eq("true")
        end
      end
    end
    it "should return false when domain is not resolved" do
      with_factory do |block_factory, _|
        domain = "axentro.ax"
        block_factory.add_slow_blocks(2)
        exec_rest_api(block_factory.rest.__v1_hra(context("/api/v1/hra/#{domain}"), {domain: domain})) do |result|
          result["status"].to_s.should eq("success")
          result["result"]["resolved"].to_s.should eq("false")
        end
      end
    end
    it "should return a list of domains" do
      with_factory do |block_factory, transaction_factory|
        domains = ["domain1.ax", "domain2.ax"]
        block_factory.add_slow_blocks(2).add_slow_block(
          [transaction_factory.make_buy_domain_from_platform(domains[0], 0_i64),
           transaction_factory.make_buy_domain_from_platform(domains[1], 0_i64)]).add_slow_blocks(2)
        address = transaction_factory.sender_wallet.address
        exec_rest_api(block_factory.rest.__v1_hra_lookup(context("/api/v1/hra/lookup/#{address}"), {address: address})) do |result|
          result["status"].to_s.should eq("success")
          result_domains = Array(DomainResult).from_json(result["result"]["domains"].to_json)
          result_domains.first.domain_name.should eq(domains[0])
          result_domains[1].domain_name.should eq(domains[1])
        end
      end
    end
    it "should return the correct list of domains after a domain has been sold" do
      with_factory do |block_factory, transaction_factory|
        domain_name = "domain1.ax"
        domain_name2 = "domain2.ax"
        block_factory.add_slow_blocks(2).add_slow_block(
          [transaction_factory.make_buy_domain_from_platform(domain_name, 0_i64),
           transaction_factory.make_buy_domain_from_platform(domain_name2, 0_i64),
          ])
          .add_slow_blocks(2)
          .add_slow_block([transaction_factory.make_sell_domain(domain_name, 100_i64)])
          .add_slow_block([transaction_factory.make_send(2000000000)])
          .add_slow_block([transaction_factory.make_buy_domain_from_seller(domain_name, 100_i64)])
          .add_slow_blocks(2)
        address = transaction_factory.sender_wallet.address
        exec_rest_api(block_factory.rest.__v1_hra_lookup(context("/api/v1/hra/lookup/#{address}"), {address: address})) do |result|
          result["status"].to_s.should eq("success")
          result_domains = Array(DomainResult).from_json(result["result"]["domains"].to_json)
          result_domains.size.should eq(1)
          result_domains.first.domain_name.should eq(domain_name2)
        end
      end
    end
  end

  describe "__v1_tokens" do
    it "should return a list of existing tokens" do
      with_factory do |block_factory, transaction_factory|
        token = "KINGS"
        block_factory.add_slow_blocks(10).add_slow_block([transaction_factory.make_create_token(token, 10000_i64)]).add_slow_blocks(3)
        exec_rest_api(block_factory.rest.__v1_tokens(context("/api/v1/tokens"), no_params)) do |result|
          result["status"].to_s.should eq("success")
          result["result"].to_s.should eq("[\"AXNT\", \"KINGS\"]")
        end
      end
    end
  end

  describe "__v1_node" do
    it "should return info about the connecting node" do
      with_factory do |block_factory, _|
        exec_rest_api(block_factory.rest.__v1_node(context("/api/v1/node"), no_params)) do |result|
          result["status"].to_s.should eq("success")
          NodeResult.from_json(result["result"].to_json)
        end
      end
    end
  end

  describe "__v1_nodes" do
    it "should return info about the connecting node" do
      with_factory do |block_factory, _|
        exec_rest_api(block_factory.rest.__v1_nodes(context("/api/v1/nodes"), no_params)) do |result|
          result["status"].to_s.should eq("success")
          NodesResult.from_json(result["result"].to_json)
        end
      end
    end
  end

  describe "__v1_node_id" do
    it "should return a message when node is not connected to any other nodes" do
      with_factory do |block_factory, _|
        exec_rest_api(block_factory.rest.__v1_node_id(context("/api/v1/node/node_id"), {id: "node_id"})) do |result|
          result["status"].to_s.should eq("error")
          result["reason"].to_s.should eq("the node node_id not found. (only searching nodes which are currently connected.)")
        end
      end
    end
  end

  describe "__v1_transaction" do
    it "should create a signed transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction = {"transaction" => transaction_factory.make_send(100_i64)}.to_json
        body = IO::Memory.new(transaction)
        exec_rest_api(block_factory.rest.__v1_transaction(context("/api/v1/node/node_id", "POST", body), no_params)) do |result|
          result["status"].to_s.should eq("success")
          Transaction.from_json(result["result"].to_json)
        end
      end
    end
  end

  describe "__v1_transaction_unsigned" do
    it "should create a unsigned transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction_id = Transaction.create_id
        unsigned_transaction = TransactionDecimal.new(
          transaction_id,
          "send", # action
          [a_decimal_sender(transaction_factory.sender_wallet, "1")],
          [a_decimal_recipient(transaction_factory.recipient_wallet, "1")],
          "0",           # message
          TOKEN_DEFAULT, # token
          "0",           # prev_hash
          0_i64,         # timestamp
          0,             # scaled
          TransactionKind::SLOW
        )
        body = IO::Memory.new(unsigned_transaction.to_json)
        exec_rest_api(block_factory.rest.__v1_transaction_unsigned(context("/api/v1/node/node_id", "POST", body), no_params)) do |result|
          result["status"].to_s.should eq("success")
          Transaction.from_json(result["result"].to_json)
        end
      end
    end
  end
end

struct DomainResult
  include JSON::Serializable
  property domain_name : String
  property address : String
  property status : Int64
  property price : String
end

struct NodeResult
  include JSON::Serializable
  property id : String
  property host : String
  property port : Int64
  property ssl : Bool
  property type : String
  property is_private : Bool
end

struct NodesResult
  include JSON::Serializable
  property successor_list : Array(String)
  property predecessor : Nil
  property private_nodes : Array(String)
end

def context(url : String, method : String = "GET", body : IO = IO::Memory.new)
  MockContext.new(method, url, body).unsafe_as(HTTP::Server::Context)
end

def no_params
  {} of String => String
end
