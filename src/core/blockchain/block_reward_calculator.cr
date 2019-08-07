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

struct BlockRewardCalculator

  getter exponential : Float32
  getter max_blocks : Int64

  def initialize(@first_block_reward : Float32, @total_reward : Float32, @max_blocks : Int64)
    @exponential = 1 - @first_block_reward / @total_reward
  end

  def reward_for_block(block_index : Int64)
   return 0_i64 if block_index >= @max_blocks
   scale_i64((@first_block_reward * (@exponential ** block_index)).to_s)
  end

  def self.init
    BlockRewardCalculator.new(12, 23_000_000, 4_000_000_i64)
  end

end
