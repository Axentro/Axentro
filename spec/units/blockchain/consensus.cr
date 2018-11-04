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

require "./../../spec_helper"
require "./../../../src/cli/modules/logger"

include Sushi::Core
include Sushi::Core::Consensus
include Sushi::Interface::Logger

describe Consensus do
  describe "#valid?, #valid_scryptn?" do
    it "should return true when is valid" do
      valid_nonce?("block_hash", 656_u64, 2).should be_true
      valid_scryptn?("block_hash", 656_u64, 2).should be_true
    end

    it "should return false when is invalid" do
      ENV.delete("SC_SET_DIFFICULTY")
      valid_nonce?("block_hash", 0_u64, 2).should be_false
      valid_scryptn?("block_hash", 0_u64, 2).should be_false
    end
  end

  describe "#valid_sha256?" do
    it "should return true when valid" do
      valid_sha256?("0", 563_u64, 2_i32).should be_true
    end

    it "should return false when invalid" do
      valid_sha256?("0", 0_u64, 2_i32).should be_false
    end
  end

  describe "difficulty" do
    describe "should return the #block_diffulty over time" do
      current_env = ENV["SC_SET_DIFFICULTY"]?
      ENV.delete("SC_SET_DIFFICULTY")

      it "should maintain difficulty when average block time is within lower and upper bounds (10 secs -> 40 secs)" do
        block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 3_i32)
        block_times = (0..1008).map{|n| 10_i64 }
        block_difficulty(100000_i64, block, block_times).should eq(3)
      end

      it "should raise difficulty when average block time is quicker than lower bounds (less than 10 secs on average)" do
        block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 3_i32)
        block_times = (0..1008).map{|n| 9_i64 }
        block_difficulty(100000_i64, block, block_times).should eq(4)
      end

      it "should lower difficulty when average block time exceeds the upper bounds (greater than 40 secs on average)" do
        block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 3_i32)
        block_times = (0..1008).map{|n| 100_i64 }
        block_difficulty(100000_i64, block, block_times).should eq(2)
      end

      ENV["SC_SET_DIFFICULTY"] = current_env
    end
  end

  STDERR.puts "< Consensus"
end
