require "./../../spec_helper"

include Sushi::Core
include Sushi::Core::Consensus

describe Consensus do

  describe "#valid?" do

    it "should return true when is valid" do
      valid?(1_i64, "block_hash", 656_u64, 2).should be_true
    end

    it "should return false when is invalid" do
        valid?(1_i64, "block_hash", 0_u64, 2).should be_false
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
end
