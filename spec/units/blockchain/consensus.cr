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
      valid_nonce?(1_i64, "block_hash", 656_u64, 2).should be_true
      valid_scryptn?(1_i64, "block_hash", 656_u64, 2).should be_true
    end

    it "should return false when is invalid" do
      ENV.delete("SC_SET_DIFFICULTY")
      valid_nonce?(1_i64, "block_hash", 0_u64, 2).should be_false
      valid_scryptn?(1_i64, "block_hash", 0_u64, 2).should be_false
    end
  end

  describe "#valid_sha256?" do
    it "should return true when valid" do
      valid_sha256?(0_i64, "0", 563_u64, 2_i32).should be_true
    end

    it "should return false when invalid" do
      valid_sha256?(0_i64, "0", 0_u64, 2_i32).should be_false
    end
  end

  describe "difficulty" do
    it "should return the #difficulty_at for the blockchain over time" do
      current_env = ENV["SC_SET_DIFFICULTY"]?
      ENV.delete("SC_SET_DIFFICULTY")

      block_zero_time_diff_3 = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 3_i32)
      block_difficulty(5_i64, block_zero_time_diff_3).should eq(4) # difficulty +1 when < 5 sec

      block_61_time_diff_3 = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 61_i64, 3_i32)
      block_difficulty(662_i64, block_61_time_diff_3).should eq(2) # difficulty -1 when > 60 sec

      block_81_time_diff_3 = Block.new(0_i64, [] of Transaction, 0_u64, "genesis", 81_i64, 3_i32)
      block_difficulty(6082_i64, block_81_time_diff_3).should eq(1) # difficulty -2 when > 80 sec

      ENV["SC_SET_DIFFICULTY"] = current_env
    end
  end

  STDERR.puts "< Consensus"
end
