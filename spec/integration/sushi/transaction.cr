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

describe "sushi transaction" do
  it "create" do
    address = "VDAwY2M4N2NiODliZTkwMjhkMzAyZDQ2MWNjNDBlY2RiYzllMzA4MDkyMTZlZjQ5"
    system_sushi(["tx", "create", "-n", node, "-w", wallet(0), "-f", "1", "-m", "10", "-a", address]).should be_true
    system_sushi(["tx", "create", "-n", node, "-w", wallet(0), "-f", "1", "-m", "10", "-a", address, "--action=send"]).should be_true
    system_sushi(["tx", "create", "-n", node, "-w", wallet(0), "-f", "1", "-m", "10", "-a", address, "--action=send", "--json"]).should be_true
  end

  it "transactions" do
    address = "VDAwY2M4N2NiODliZTkwMjhkMzAyZDQ2MWNjNDBlY2RiYzllMzA4MDkyMTZlZjQ5"
    system_sushi(["tx", "transactions", "-n", node, "-i", "1"]).should be_true
    system_sushi(["tx", "transactions", "-n", node, "-a", address]).should be_true
  end

  it "transaction and confirmation" do
    address = "VDAwY2M4N2NiODliZTkwMjhkMzAyZDQ2MWNjNDBlY2RiYzllMzA4MDkyMTZlZjQ5"
    tx = JSON.parse(exec_sushi(["tx", "create", "-n", node, "-w", wallet(0), "-f", "1", "-m", "10", "-a", address, "--json"]))

    wait_mining(1)

    system_sushi(["tx", "transaction", "-n", node, "-t", tx["id"].as_s]).should be_true
    system_sushi(["tx", "confirmation", "-n", node, "-t", tx["id"].as_s]).should be_true
    system_sushi(["tx", "confirmation", "-n", node, "-t", tx["id"].as_s, "--json"]).should be_true
  end

  it "fees" do
    system_sushi(["tx", "fees", "-n", node]).should be_true
    system_sushi(["tx", "fees", "-n", node, "--json"]).should be_true
  end

  STDERR.puts "< sushi transaction"
end
