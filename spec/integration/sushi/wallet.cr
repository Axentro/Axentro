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

describe "sushi wallet" do
  it "create and verify" do
    system_sushi(["wt", "create", "-w", wallet(2)]).should be_true
    system_sushi(["wt", "verify", "-w", wallet(2)]).should be_true

    File.delete(wallet(2))
  end

  it "encrypt and decrypt" do
    # todo
    # may be broken
  end

  it "amount" do
    address = "VDAwY2M4N2NiODliZTkwMjhkMzAyZDQ2MWNjNDBlY2RiYzllMzA4MDkyMTZlZjQ5"
    system_sushi(["wt", "amount", "-n", node, "-a", address]).should be_true
    system_sushi(["wt", "amount", "-n", node, "-a", address, "--token=SHARI"]).should be_true
    system_sushi(["wt", "amount", "-n", node, "-a", address, "--token=SHARI", "--json"]).should be_true
  end

  STDERR.puts "< sushi wallet"
end
