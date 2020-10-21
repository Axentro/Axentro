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
    on.get_config.should eq({"testnet" => {"fastnodes" => ["VDBkMzRmOWZlYWEwYmM4OWY4MjZhNDlmZThhNTY1MmI3NzZjYTNkZjVlNzYzMjZi"], "slownodes" => ["VDAyNThiOWFiN2Q5YWM3ZjUyYTNhYzQwZTY1NDBmYWJkMjczZmVmZThlOTgzMWM4"]}, "mainnet" => {"fastnodes" => ["VDAwZDRiYTg0MWVlZjE4M2U3OWY2N2E0YmZkZDJjN2JmMWE0ZTViMjE3ZDNmZTU1"], "slownodes" => ["VDBiYjkyMjY1ZDJlOTNkZmNjN2NmYWFhZTVhMzVlYjZmYjY2YzllNWFjYWY3N2Nh"]}})
  end

  describe "testnet nodes" do
    it "should return all nodes for" do
      on = OfficialNodes.new("#{__DIR__}/../../utils/data/official_nodes.yml")
      on.all_for("testnet").should eq(["VDBkMzRmOWZlYWEwYmM4OWY4MjZhNDlmZThhNTY1MmI3NzZjYTNkZjVlNzYzMjZi", "VDAyNThiOWFiN2Q5YWM3ZjUyYTNhYzQwZTY1NDBmYWJkMjczZmVmZThlOTgzMWM4"])
    end

    it "should return all slow nodes" do
      on = OfficialNodes.new("#{__DIR__}/../../utils/data/official_nodes.yml")
      on.all_slow_for("testnet").should eq(["VDAyNThiOWFiN2Q5YWM3ZjUyYTNhYzQwZTY1NDBmYWJkMjczZmVmZThlOTgzMWM4"])
    end

    it "should return all fast nodes" do
      on = OfficialNodes.new("#{__DIR__}/../../utils/data/official_nodes.yml")
      on.all_fast_for("testnet").should eq(["VDBkMzRmOWZlYWEwYmM4OWY4MjZhNDlmZThhNTY1MmI3NzZjYTNkZjVlNzYzMjZi"])
    end

    it "should remove duplicates" do
      on = OfficialNodes.new("#{__DIR__}/../../utils/data/official_nodes_duplicates.yml")
      on.all_for("testnet").should eq(["VDBkMzRmOWZlYWEwYmM4OWY4MjZhNDlmZThhNTY1MmI3NzZjYTNkZjVlNzYzMjZi", "VDAyNThiOWFiN2Q5YWM3ZjUyYTNhYzQwZTY1NDBmYWJkMjczZmVmZThlOTgzMWM4"])
      on.all_fast_for("testnet").should eq(["VDBkMzRmOWZlYWEwYmM4OWY4MjZhNDlmZThhNTY1MmI3NzZjYTNkZjVlNzYzMjZi"])
      on.all_slow_for("testnet").should eq(["VDAyNThiOWFiN2Q5YWM3ZjUyYTNhYzQwZTY1NDBmYWJkMjczZmVmZThlOTgzMWM4"])
    end
  end

  describe "mainnet nodes" do
    it "should return all nodes for" do
      on = OfficialNodes.new("#{__DIR__}/../../utils/data/official_nodes.yml")
      on.all_for("mainnet").should eq(["VDAwZDRiYTg0MWVlZjE4M2U3OWY2N2E0YmZkZDJjN2JmMWE0ZTViMjE3ZDNmZTU1", "VDBiYjkyMjY1ZDJlOTNkZmNjN2NmYWFhZTVhMzVlYjZmYjY2YzllNWFjYWY3N2Nh"])
    end

    it "should return all slow nodes" do
      on = OfficialNodes.new("#{__DIR__}/../../utils/data/official_nodes.yml")
      on.all_slow_for("mainnet").should eq(["VDBiYjkyMjY1ZDJlOTNkZmNjN2NmYWFhZTVhMzVlYjZmYjY2YzllNWFjYWY3N2Nh"])
    end

    it "should return all fast nodes" do
      on = OfficialNodes.new("#{__DIR__}/../../utils/data/official_nodes.yml")
      on.all_fast_for("mainnet").should eq(["VDAwZDRiYTg0MWVlZjE4M2U3OWY2N2E0YmZkZDJjN2JmMWE0ZTViMjE3ZDNmZTU1"])
    end
  end
end
