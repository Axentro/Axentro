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

include Units::Utils
include Axentro::Core
include Axentro::Core::TransactionModels
include ::Axentro::Common::Denomination
include Hashes

MAX_BLOCKS      = 8_000_000_i64
COIN_CAP        = BigDecimal.new(46_000_000)
STARTING_REWARD = BigDecimal.new(12)

describe BlockRewardCalculator do
  it "should return the correct block reward based on the supplied index with init" do
    assert_calcs(BlockRewardCalculator.init)
  end

  it "should return the correct block reward based on the supplied index" do
    assert_calcs(BlockRewardCalculator.new(STARTING_REWARD, COIN_CAP, MAX_BLOCKS))
  end
end

def assert_calcs(calc)
  calc.reward_for_block(0_i64).should eq(1200000000)
  calc.reward_for_block(1238291_i64).should eq(868740410)
  calc.reward_for_block(756752_i64).should eq(985021279)
  calc.reward_for_block(MAX_BLOCKS).should eq(0)
end
