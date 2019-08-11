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

module ::Sushi::Core
  struct BlockRewardCalculator
    getter exponential : Float32
    getter max_blocks : Int64

    def initialize(@first_block_reward : Float32, @total_reward : Float32, @max_blocks : Int64)
      @exponential = 1 - @first_block_reward / @total_reward
    end

    def reward_for_block(block_index : Int64, total_premine_value : Int64)
      premine_index = premine_as_index(total_premine_value, block_index)
      get_block_reward(block_index + premine_index)
    end

    private def get_block_reward(block_index : Int64)
      return 0_i64 if block_index >= @max_blocks
      scale_i64((@first_block_reward * (@exponential ** block_index)).to_s)
    end

    private def premine_as_index(premine_value : Int64, current_index : Int64) : Int64
      return 0_i64 if (premine_value <= 0_i64 || current_index > 0)
      accumulated_value = 0_i64
      index = 0_i64
      (0_i64..@max_blocks).each do |_|
        value = get_block_reward(index)
        accumulated_value += value
        break if accumulated_value >= premine_value
        index += 1
      end
      debug "accumulated_value: #{accumulated_value} -> premine_value: #{premine_value}, index: #{index}"
      index
    end

    def self.init
      BlockRewardCalculator.new(12, 23_000_000, 4_000_000_i64)
    end
  end

  include Logger
end
