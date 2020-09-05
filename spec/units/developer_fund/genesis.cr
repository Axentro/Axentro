# Copyright © 2017-2018 The Axentro Core developers
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
    node = Axentro::Core::Node.new(true, true, "bind_host", 8008_i32, nil, nil, nil, nil, nil, node_wallet, database, nil, nil, 512, 512, false)
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
    node = Axentro::Core::Node.new(true, true, "bind_host", 8008_i32, nil, nil, nil, nil, nil, node_wallet, database, developer_fund, nil, 512, 512, false)
    blockchain = node.blockchain
    blockchain.setup(node)

    genesis_block = blockchain.chain.first
    genesis_block.prev_hash.should eq("genesis")
    expected_recipients = [{address: "VDAwZTdkZGNjYjg1NDA1ZjdhYzk1M2ExMDAzNmY5MjUyYjI0MmMwNGJjZWY4NjA3", amount: 500000000000}, {address: "VDBjY2NmOGMyZmQ0MDc4NTIyNDBmYzNmOWQ3M2NlMzljODExOTBjYTQ0ZjMxMGFl", amount: 900000000000}]
    genesis_block.transactions.flat_map(&.recipients).sort_by(&.["amount"]).should eq(expected_recipients)
  end
end
