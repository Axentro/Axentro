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

module ::Axentro::Core::NodeComponents
  def subchain_algo(slow_start : Int64, fast_start : Int64, chunk_size : Int32) : Blockchain::Chain
    highest_index = Math.max(slow_start, fast_start).to_i32
    lowest_index = Math.min(slow_start, fast_start).to_i32

    start = lowest_index
    finish = highest_index + chunk_size * 3

    ids = @blockchain.database.batch_by_time(start, finish)
    slow = ids.select { |b| b.index.even? && (slow_start == 0_i64 ? (b.index >= slow_start) : (b.index > slow_start)) }
    fast = ids.select { |b| b.index.odd? && b.index > fast_start }

    blocks = (slow + fast).sort_by(&.timestamp)

    blocks.first(chunk_size)
  end
end
