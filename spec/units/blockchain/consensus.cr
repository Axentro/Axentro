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

include Sushi::Core
include Sushi::Core::Consensus

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

      it "should return 4 when difficulty starts at 6 and ratio > 100.0" do
        block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 6_i32)
        block_difficulty(100000_i64, block).should eq(4)
      end

      it "should return minimum difficulty if calculated difficulty is less than the minimum of 3 - when ratio > 100.0" do
        block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 3_i32)
        block_difficulty(100000_i64, block).should eq(3)
      end

      it "should return 4 when difficulty starts at 6 and ratio > 10.0 but < 100.0" do
        block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 6_i32)
        block_difficulty(100000_i64, block).should eq(4)
      end

      it "should return minimum difficulty if calculated difficulty is less than the minimum of 3 - when ratio > 10.0 but < 100.0" do
        block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 6_i32)
        block_difficulty(5000_i64, block).should eq(5)
      end

      it "should return current difficulty + 1 when ratio is < 0.1" do
        block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 6_i32)
        block_difficulty(5_i64, block).should eq(7)
      end

      it "should return current difficulty with no change when ratio is > 0.1 but < 10.0" do
        block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 6_i32)
        block_difficulty(95_i64, block).should eq(6)
      end

      ENV["SC_SET_DIFFICULTY"] = current_env
    end
  end

  STDERR.puts "< Consensus"
end
