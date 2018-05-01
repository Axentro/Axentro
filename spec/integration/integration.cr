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

# todo
`shards build`

require "./utils"

include ::Utils::Integration

describe "for preparation" do
  describe "checking the existance of the binaries" do
    it "`sushi` should be existed (if not, please build them first)" do
      File.exists?("#{bin}/sushi").should be_true
    end

    it "`sushid` should be existed (if not, please build them first)" do
      File.exists?("#{bin}/sushid").should be_true
    end

    it "`sushim` should be existed (if not, please build them first)" do
      File.exists?("#{bin}/sushim").should be_true
    end
  end

  describe "checking the existance of the wallets" do
    it "spec/integration/wallets/testnet-[0, 1].json should be existed" do
      File.exists?(wallet(0)).should be_true
      File.exists?(wallet(1)).should be_true
    end
  end

  STDERR.puts "< Preparation"
end

kill_all

start_node

sleep 2

start_mining

puts ""
print light_green("preparing node ")

loop do
  print light_green(".")

  sleep 1

  wallet0 = JSON.parse(exec_sushi(["wt", "amount", "-n", node, "-w", wallet(0), "-u", "--json"]))
  wallet1 = JSON.parse(exec_sushi(["wt", "amount", "-n", node, "-w", wallet(1), "-u", "--json"]))

  size = JSON.parse(exec_sushi(["bc", "size", "-n", "http://127.0.0.1:3100", "--json"]))

  break if wallet0["pairs"][0]["token"] == TOKEN_DEFAULT &&
           wallet0["pairs"][0]["amount"].as_i64 > 1000 &&
           wallet1["pairs"][0]["token"] == TOKEN_DEFAULT &&
           wallet1["pairs"][0]["amount"].as_i64 > 1000 &&
           size["size"].as_i > 5
end

puts ""
puts light_green("done!")
puts ""

kill_miner

require "./sushi/blockchain"
require "./sushi/scars"
require "./sushi/token"

kill_all
