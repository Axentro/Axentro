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

MAX_BLOCKS      =  4_000_000_i64
COIN_CAP        = 23_000_000_f32
STARTING_REWARD =         12_f32

describe BlockRewardCalculator do
  it "should return the correct block reward based on the supplied index" do
    calc = BlockRewardCalculator.new(STARTING_REWARD, COIN_CAP, MAX_BLOCKS)
    count = 0_i64
    (0_i64..MAX_BLOCKS).each do |i|
      c = calc.reward_for_block(i, 0_i64)
      count += c
    end
    p scale_decimal(count)
  end
end
