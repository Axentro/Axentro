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

describe OfficialNodes do
  it "should successfully parse the offical nodes yml file and get the contents" do
    OfficialNodes.validate("#{__DIR__}/../../utils/data/official_nodes.yml")
  end

  it "should return nil if nil is supplied for path" do
    OfficialNodes.validate(nil).should be_nil
  end

  it "should raise an invalid official nodes file if the file extension is not .yml" do
    expect_raises(Exception, "Official nodes input file must be a valid .yml file - you supplied official_nodes.txt") do
      OfficialNodes.validate("official_nodes.txt")
    end
  end

  it "should raise an error if any of the supplied addresses are invalid" do
    expect_raises(Exception, "The supplied address: invalid_address is invalid") do
      OfficialNodes.validate("#{__DIR__}/../../utils/data/official_nodes_invalid.yml")
    end
  end

  it "should return the config" do
    on = OfficialNodes.new("#{__DIR__}/../../utils/data/official_nodes.yml")
    on.get_config.should eq({"fastnodes" => ["VDBkMzRmOWZlYWEwYmM4OWY4MjZhNDlmZThhNTY1MmI3NzZjYTNkZjVlNzYzMjZi"], "slownodes" => ["VDAyNThiOWFiN2Q5YWM3ZjUyYTNhYzQwZTY1NDBmYWJkMjczZmVmZThlOTgzMWM4"]})
  end

  it "should make official node transactions with a coinbase when no developer fund is present" do
    on = OfficialNodes.new("#{__DIR__}/../../utils/data/official_nodes.yml")
    transactions = OfficialNodes.transactions(on.get_config, [] of Axentro::Core::Transaction)

    coinbase = transactions.select(&.is_coinbase?)
    coinbase.size.should eq(1)

    official_node_slow = transactions.select(&.action.==("create_official_node_slow"))
    official_node_slow.size.should eq(1)

    official_node_fast = transactions.select(&.action.==("create_official_node_slow"))
    official_node_fast.size.should eq(1)

    transactions[0].prev_hash.should eq("0")
    transactions[1].prev_hash.should eq(transactions[0].to_hash)
    transactions[2].prev_hash.should eq(transactions[1].to_hash)
  end

  it "should make official node transactions with a coinbase when developer fund is present" do
    df = DeveloperFund.validate("#{__DIR__}/../../utils/data/developer_fund.yml")
    fund_transactions = DeveloperFund.transactions(df.not_nil!.get_config)

    on = OfficialNodes.new("#{__DIR__}/../../utils/data/official_nodes.yml")
    transactions = OfficialNodes.transactions(on.get_config, fund_transactions)

    coinbase = transactions.select(&.is_coinbase?)
    coinbase.size.should eq(0)

    official_node_slow = transactions.select(&.action.==("create_official_node_slow"))
    official_node_slow.size.should eq(1)

    official_node_fast = transactions.select(&.action.==("create_official_node_fast"))
    official_node_fast.size.should eq(1)

    transactions[0].prev_hash.should eq(fund_transactions[-1].to_hash)
    transactions[1].prev_hash.should eq(transactions[0].to_hash)
  end
end
