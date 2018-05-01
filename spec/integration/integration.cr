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

require "./sushi/blockchain"
