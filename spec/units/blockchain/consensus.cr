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
      valid_nonce?("block_hash", 0_u64, 20).should be_false
      valid_scryptn?("block_hash", 0_u64, 20).should be_false
    end
  end

  describe "difficulty" do
    describe "should return the #block_diffulty over time" do
      current_env = ENV["SC_SET_DIFFICULTY"]?
      ENV.delete("SC_SET_DIFFICULTY")

      it "should return 10 when block averages are empty" do
        block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 20_i32)
        block_times = [] of Int64
        block_difficulty(100000_i64, 10_i64, block, block_times).should eq(10)
      end

      describe "when using elapsed block time (before block averages are built)" do
        it "should maintain difficulty when average block time is within lower and upper bounds (10 secs -> 40 secs)" do
          block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 20_i32)
          block_times = [10_i64, 10_i64] of Int64
          block_difficulty(100000_i64, 10_i64, block, block_times).should eq(20)
        end

        it "should raise difficulty when average block time is quicker than lower bounds (less than 10 secs on average)" do
          block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 20_i32)
          block_times = [10_i64, 10_i64] of Int64
          block_difficulty(100000_i64, 9_i64, block, block_times).should eq(21)
        end

        it "should lower difficulty when average block time exceeds the upper bounds (greater than 40 secs on average)" do
          block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 20_i32)
          block_times = [10_i64, 10_i64] of Int64
          block_difficulty(100000_i64, 100_i64, block, block_times).should eq(19)
        end
      end

      describe "when using average block time (after block averages are built)" do
        it "should maintain difficulty when average block time is within lower and upper bounds (10 secs -> 40 secs)" do
          block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 20_i32)
          block_times = (0..730).map { |n| 10_i64 }
          block_difficulty(100000_i64, 9_i64, block, block_times).should eq(20)
        end

        it "should raise difficulty when average block time is quicker than lower bounds (less than 10 secs on average)" do
          block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 20_i32)
          block_times = (0..730).map { |n| 9_i64 }
          block_difficulty(100000_i64, 11_i64, block, block_times).should eq(21)
        end

        it "should lower difficulty when average block time exceeds the upper bounds (greater than 40 secs on average)" do
          block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 20_i32)
          block_times = (0..730).map { |n| 100_i64 }
          block_difficulty(100000_i64, 9_i64, block, block_times).should eq(19)
        end
      end

      ENV["SC_SET_DIFFICULTY"] = current_env
    end
  end

  STDERR.puts "< Consensus"
end
