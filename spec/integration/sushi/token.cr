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

describe "sushi token" do
  it "create" do
    system_sushi(["tk", "create", "-n", node, "-w", wallet(0), "-f", "1000", "-m", "1000000", "--token=TESTTOKEN"]).should be_true
    system_sushi(["tk", "create", "-n", node, "-w", wallet(0), "-f", "1000", "-m", "1000000", "--token=TESTTOKEN2", "--json"]).should be_true
  end

  it "list" do
    system_sushi(["tk", "list", "-n", node]).should be_true
    system_sushi(["tk", "list", "-n", node, "--json"]).should be_true
  end
end
