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

class ChainIntegrity
  def initialize(@max_slow_block_id : Int64, @max_fast_block_id : Int64, @security_level_percentage : Int64)
  end

  def get_validation_block_ids_for_slow : Array(Int64)
    blocks = (0_i64..@max_slow_block_id).to_a.reject(&.odd?)

    rejections = blocks.last(10)
    backed_off = blocks.reject { |b| rejections.includes?(b) }

    percentage_slow = (backed_off.size*@security_level_percentage*0.01).ceil.to_i
    percent_slow = backed_off.shuffle.first(percentage_slow)

    ([0_i64] + percent_slow).uniq.sort
  end

  def get_validation_block_ids_for_fast : Array(Int64)
    blocks = (0_i64..@max_fast_block_id).to_a.reject(&.even?)

    rejections = blocks.last(10)
    backed_off = blocks.reject { |b| rejections.includes?(b) }

    percentage_fast = (backed_off.size*@security_level_percentage*0.01).ceil.to_i
    percent_fast = backed_off.shuffle.first(percentage_fast)

    percent_fast.uniq.sort
  end

  def get_validation_block_ids : Array(Int64)
    (get_validation_block_ids_for_slow + get_validation_block_ids_for_fast).uniq.sort
  end
end
