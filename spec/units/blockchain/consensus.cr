# Copyright © 2017-2018 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "./../../spec_helper"
require "./../../../src/cli/modules/logger"

include Axentro::Core
include Axentro::Core::Consensus
include Axentro::Interface::Logger
include Units::Utils


describe Consensus do
  describe "#valid?, #valid_pow?" do
    # TODO: this test is probably erroneously passing since the change to the 'valid' methods
    it "should return a valid difficulty value" do
      ENV.delete("SC_SET_DIFFICULTY")
      nonce = "2978736204850283095"
      valid_nonce?("block_hash", nonce, 2).should be < 3
      valid_pow?("block_hash", nonce, 2).should be < 3
    end

    # TODO: this test is probably erroneously passing since the change to the 'valid' methods
    it "should return an invalid difficulty value" do
      ENV.delete("SC_SET_DIFFICULTY")
      nonce = "2978736204850283095"
      valid_nonce?("block_hash", nonce, 20).should be < 3
      valid_pow?("block_hash", nonce, 20).should be < 3
    end
  end

  describe "difficulty" do
    describe "should return the #block_diffulty over time" do
      current_env = ENV["SC_SET_DIFFICULTY"]?
      ENV.delete("SC_SET_DIFFICULTY")

      describe "(before block Dark Gravity Wave running average can be built)" do
        it "should use default difficulty when less than 3 blocks in the chain" do
          with_factory do |block_factory|
            block_factory.add_slow_block.chain
            block_difficulty(block_factory.blockchain).should eq(Consensus::DEFAULT_DIFFICULTY_TARGET)
          end
        end

        it "should lower difficulty when average block time is longer than the desired secondss on average" do
          number_of_blocks = 30
          timestamp = __timestamp - (number_of_blocks * Consensus::POW_TARGET_SPACING.to_i64)
          with_factory do |block_factory|
            chain = block_factory.add_slow_blocks(number_of_blocks).chain
            chain.each do |block|
              block = block.as(SlowBlock)
              block.timestamp = timestamp
              block.difficulty = Consensus::DEFAULT_DIFFICULTY_TARGET
              timestamp += Consensus::POW_TARGET_SPACING.to_i64 + 5000
            end
            block_difficulty(block_factory.blockchain).should be < Consensus::DEFAULT_DIFFICULTY_TARGET
          end
        end

        it "should raise difficulty when average block time is shorter than the desired secondss on average" do
          number_of_blocks = 30
          timestamp = __timestamp - (number_of_blocks * Consensus::POW_TARGET_SPACING.to_i64)
          with_factory do |block_factory|
            chain = block_factory.add_slow_blocks(number_of_blocks).chain
            chain.each do |block|
              block = block.as(SlowBlock)
              block.timestamp = timestamp
              block.difficulty = Consensus::DEFAULT_DIFFICULTY_TARGET
              timestamp += Consensus::POW_TARGET_SPACING.to_i64 - 5000
            end
            block_difficulty(block_factory.blockchain).should be > Consensus::DEFAULT_DIFFICULTY_TARGET
          end
        end
      end

      ENV["SC_SET_DIFFICULTY"] = current_env
    end
  end
end
