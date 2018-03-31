require "./../../spec_helper"

include Sushi::Core
include Sushi::Core::Models
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
      difficulty_at(0_i64).should eq(4)
    end

    it "should return the #miner_difficulty_at for the miners" do
      miner_difficulty_at(0_i64).should eq(3)
    end
  end

  STDERR.puts "< Consensus"
end
