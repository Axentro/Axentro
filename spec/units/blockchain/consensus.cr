# Copyright © 2017-2020 The Axentro Core developers
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
  describe "calculate_pow_difficulty" do
    it "should return a valid difficulty value" do
      ENV.delete("AX_SET_DIFFICULTY")
      hash = "e33598878258c85c60c5c29a41ad756cb69ecd315154695970c375a792eb8f4e"
      nonce = "17186779519462547558"
      calculate_pow_difficulty(hash, nonce, 13).should eq(13)
    end
  end

  describe "is_nonce_valid?" do
    it "when valid" do
      ENV.delete("AX_SET_DIFFICULTY")
      hash = "e33598878258c85c60c5c29a41ad756cb69ecd315154695970c375a792eb8f4e"
      nonce = "17186779519462547558"
      is_nonce_valid?(hash, nonce, 13).should eq(true)
    end
    it "when invalid" do
      ENV.delete("AX_SET_DIFFICULTY")
      hash = "e33598878258c85c60c5c29a41ad756cb69ecd315154695970c375a792eb8f4e"
      nonce = "17186779519462547559"
      is_nonce_valid?(hash, nonce, 13).should eq(false)
    end
  end

  describe "difficulty" do
    describe "should return the #block_diffulty over time" do
      current_env = ENV["AX_SET_DIFFICULTY"]?
      ENV.delete("AX_SET_DIFFICULTY")

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

      ENV["AX_SET_DIFFICULTY"] = current_env
    end
  end
end
