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

describe "sushi scars" do
  it "buy, sell, cancel and resolve" do
    #
    # buy
    #
    system_sushi(["sc", "buy", "-n", node, "-w", wallet(0), "-f", "100", "--price=0", "--domain=abc.sc"]).should be_true
    system_sushi(["sc", "buy", "-n", node, "-w", wallet(0), "-f", "100", "--price=0", "--domain=def.sc", "--json"]).should be_true

    wait_mining(1)

    #
    # sell
    #
    system_sushi(["sc", "sell", "-n", node, "-w", wallet(0), "-f", "10", "--price=0", "--domain=abc.sc"]).should be_true
    system_sushi(["sc", "sell", "-n", node, "-w", wallet(0), "-f", "10", "--price=0", "--domain=def.sc", "--json"]).should be_true

    wait_mining(1)

    #
    # cancel
    #
    system_sushi(["sc", "cancel", "-n", node, "-w", wallet(0), "-f", "1", "--domain=abc.sc"]).should be_true
    system_sushi(["sc", "cancel", "-n", node, "-w", wallet(0), "-f", "1", "--domain=def.sc", "--json"]).should be_true

    #
    # resolve
    #
    system_sushi(["sc", "resolve", "-n", node, "-w", wallet(0), "--domain=abc.sc"]).should be_true
    system_sushi(["sc", "resolve", "-n", node, "-w", wallet(0), "--domain=def.sc", "--json"]).should be_true
  end

  it "sales" do
    system_sushi(["sc", "sales", "-n", node]).should be_true
    system_sushi(["sc", "sales", "-n", node, "--json"]).should be_true
  end

  STDERR.puts "< sushi scars"
end
