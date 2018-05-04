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

describe "sushi blockchain" do
  it "size" do
    system_sushi(["bc", "size", "-n", node]).should be_true
    system_sushi(["bc", "size", "-n", node, "--json"]).should be_true
  end

  it "all" do
    system_sushi(["bc", "all", "-n", node]).should be_true
    system_sushi(["bc", "all", "-n", node, "--json"]).should be_true
  end

  it "block" do
    system_sushi(["bc", "block", "-n", node, "-i", "0"]).should be_true
    system_sushi(["bc", "block", "-n", node, "-i", "0", "--json"]).should be_true

    # todo:
    # show a block for transaction
  end

  STDERR.puts "< sushi blockchain"
end
