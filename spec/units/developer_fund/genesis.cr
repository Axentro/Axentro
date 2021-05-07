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

describe Blockchain do
  it "should create a genesis block with no transactions when no developer fund is provided" do
    node_wallet = Wallet.from_json(Wallet.create(true).to_json)
    database = Axentro::Core::Database.in_memory
    whitelist = [] of String
    whitelist_message = ""
    metrics_whitelist = [] of String
    node = Axentro::Core::Node.new(true, true, "bind_host", 8008_i32, nil, nil, nil, nil, nil, node_wallet, node_wallet.address, "", database, nil, nil, false, 20, 100, false, 512, 512, whitelist, whitelist_message, metrics_whitelist, false)
    blockchain = node.blockchain
    blockchain.setup(node)

    genesis_block = blockchain.chain.first
    genesis_block.prev_hash.should eq("genesis")
    genesis_block.transactions.should eq([] of Transaction)
  end

  it "should create a genesis block with the specified transactions when developer fund is provided" do
    node_wallet = Wallet.from_json(Wallet.create(true).to_json)
    database = Axentro::Core::Database.in_memory
    developer_fund = DeveloperFund.validate("#{__DIR__}/../../utils/data/developer_fund.yml")
    whitelist = [] of String
    whitelist_message = ""
    metrics_whitelist = [] of String
    node = Axentro::Core::Node.new(true, true, "bind_host", 8008_i32, nil, nil, nil, nil, nil, node_wallet, node_wallet.address, "", database, developer_fund, nil, false, 20, 100, false, 512, 512, whitelist, whitelist_message, metrics_whitelist, false)
    blockchain = node.blockchain
    blockchain.setup(node)

    genesis_block = blockchain.chain.first
    genesis_block.prev_hash.should eq("genesis")
    expected_recipients = [{address: "VDAwZTdkZGNjYjg1NDA1ZjdhYzk1M2ExMDAzNmY5MjUyYjI0MmMwNGJjZWY4NjA3", amount: 500000000000}, {address: "VDBjY2NmOGMyZmQ0MDc4NTIyNDBmYzNmOWQ3M2NlMzljODExOTBjYTQ0ZjMxMGFl", amount: 900000000000}]
    genesis_block.transactions.flat_map(&.recipients).sort_by!(&.amount).each_with_index do |r, i|
      r.address.should eq(expected_recipients[i][:address])
      r.amount.should eq(expected_recipients[i][:amount])
    end
  end
end
