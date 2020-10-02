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

module ::Axentro::Core
  struct BlockRewardCalculator
    getter exponential : BigDecimal
    getter max_blocks : Int64

    def initialize(@first_block_reward : BigDecimal, @total_reward : BigDecimal, @max_blocks : Int64)
      @exponential = 1 - @first_block_reward / @total_reward
    end

    def reward_for_block(block_index : Int64)
      return 0_i64 if block_index >= @max_blocks
      scale_i64((@first_block_reward * (BigDecimal.new(@exponential.to_f64 ** block_index))))
    end

    # Block rewards are only applicable to even index numbers for Slow Blocks
    # so double the total_reward and the max_blocks to achieve this.
    def self.init
      BlockRewardCalculator.new(BigDecimal.new(12), BigDecimal.new(46_000_000), 8_000_000_i64)
    end

    include Logger
  end
end
