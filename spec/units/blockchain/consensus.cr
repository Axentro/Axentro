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
  ENV.delete("UT")

  describe "#valid?, #valid_scryptn?" do
    it "should return true when is valid" do
      valid?(1_i64, "block_hash", 656_u64, 2).should be_true
      valid_scryptn?(1_i64, "block_hash", 656_u64, 2).should be_true
    end

    it "should return false when is invalid" do
      valid?(1_i64, "block_hash", 0_u64, 2).should be_false
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
    it "should return the #difficulty_at for the blockchain" do
      current_env = ENV["SET_DIFFICULTY"]?
      ENV.delete("SET_DIFFICULTY")

      difficulty_at(0_i64).should eq(4)

      ENV["SET_DIFFICULTY"] = current_env
    end

    it "should return the #miner_difficulty_at for the miners" do
      current_env = ENV["SET_DIFFICULTY"]?
      ENV.delete("SET_DIFFICULTY")

      miner_difficulty_at(0_i64).should eq(3)

      ENV["SET_DIFFICULTY"] = current_env
    end
  end

  STDERR.puts "< Consensus"
end
