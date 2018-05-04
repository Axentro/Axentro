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

describe "REST APIs" do
  describe "/v1" do
    it "/blockchain" do
      system_curl("v1/blockchain").should be_true
      system_curl("v1/blockchain/header").should be_true
      system_curl("v1/blockchain/size").should be_true
    end

    it "/block" do
      system_curl("v1/block/1").should be_true
      system_curl("v1/block/1/header").should be_true
      system_curl("v1/block/1/transactions").should be_true
    end

    it "transaction" do
      address = "VDAwY2M4N2NiODliZTkwMjhkMzAyZDQ2MWNjNDBlY2RiYzllMzA4MDkyMTZlZjQ5"
      tx = JSON.parse(exec_sushi(["tx", "create", "-n", node, "-w", wallet(0), "-f", "1", "-m", "10", "-a", address, "--json"]))

      wait_mining(1)

      system_curl("v1/transaction/#{tx["id"]}").should be_true
      system_curl("v1/transaction/#{tx["id"]}/block").should be_true
      system_curl("v1/transaction/#{tx["id"]}/block/header").should be_true
      system_curl("v1/transaction/#{tx["id"]}/confirmations").should be_true
      system_curl("v1/transaction/fees").should be_true
    end

    it "address" do
      address = "VDAwY2M4N2NiODliZTkwMjhkMzAyZDQ2MWNjNDBlY2RiYzllMzA4MDkyMTZlZjQ5"

      system_curl("v1/address/#{address}/transactions").should be_true
      system_curl("v1/address/#{address}/confirmed").should be_true
      system_curl("v1/address/#{address}/confirmed/SHARI").should be_true
      system_curl("v1/address/#{address}/unconfirmed").should be_true
      system_curl("v1/address/#{address}/unconfirmed/SHARI").should be_true
    end

    it "scars" do
      domain = "test.sc"

      system_curl("v1/scars/sales").should be_true
      system_curl("v1/scars/#{domain}/confirmed").should be_true
      system_curl("v1/scars/#{domain}/unconfirmed").should be_true
    end
  end

  STDERR.puts "< REST API"
end
