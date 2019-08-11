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
require "./../utils"

include Units::Utils
include Sushi::Core
include Sushi::Core::TransactionModels
include ::Sushi::Common::Denomination
include Hashes

MAX_BLOCKS      = 4_000_000_i64
COIN_CAP        = BigDecimal.new(23_000_000)
STARTING_REWARD = BigDecimal.new(12)

describe BlockRewardCalculator do
  it "should return the correct block reward based on the supplied index with init" do
    assert_calcs(BlockRewardCalculator.init)
  end

  it "should return the correct block reward based on the supplied index" do
    assert_calcs(BlockRewardCalculator.new(STARTING_REWARD, COIN_CAP, MAX_BLOCKS))
  end

  it "should return correct block reward when premine is supplied" do
    calc = BlockRewardCalculator.init
    calc.reward_for_block(1_i64, 0_i64).should eq(1199999373)
  end
end

def assert_calcs(calc)
  calc.reward_for_block(0_i64, 0_i64).should eq(1200000000)
  calc.reward_for_block(1238291_i64, 0_i64).should eq(628924864)
  calc.reward_for_block(756752_i64, 0_i64).should eq(808555726)
  calc.reward_for_block(MAX_BLOCKS, 0_i64).should eq(0)
end
