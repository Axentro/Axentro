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
  def subchain_algo(slow_start : Int64, fast_start : Int64, count : Int32) : Array(Int64)
    # raise error if count is greater than db chunk
    blocks = slow_start == 0_i64 ? [0_i64] : [] of Int64
    limit = 100
    offset = 0
    while blocks.size < count 
      ids = @blockchain.database.batch_from(limit, offset)
      puts "IDS:"
      p ids
      break if ids.empty?
      visit(slow_start, fast_start, ids, blocks)
      offset += 100
    end
    blocks
  end

  def visit(slow_start, fast_start, ids, blocks)
    ids.each do |id|
      if id.even?
        if id > slow_start
          blocks << id
        end
      else
        if id > fast_start
          blocks << id
        end
      end
    end
  end
end
