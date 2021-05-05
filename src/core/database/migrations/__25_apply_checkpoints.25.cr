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

@[MG::Tags("main")]
class ApplyCheckpoints < MG::Base
  include Axentro::Core
  include Data

  def up : String
    ""
  end

  def after_up(conn : DB::Connection)
    if highest_slow_index = conn.query_one("select max(idx) from blocks where kind = 'SLOW'", as: Int64?)
      indexes_count = highest_slow_index / Blocks::BLOCK_CHECKPOINT_SIZE / 2
      (1..indexes_count).each do |n|
        index = n * Blocks::BLOCK_CHECKPOINT_SIZE
        checkpoint = Blocks.get_checkpoint_merkle(conn, index.to_i64, BlockKind::SLOW)
        conn.exec("update blocks set checkpoint = ? where idx = ?", checkpoint, index)
      end
    end

    if highest_fast_index = conn.query_one("select max(idx) from blocks where kind = 'FAST'", as: Int64?)
      indexes_count = highest_fast_index / Blocks::BLOCK_CHECKPOINT_SIZE / 2
      (1..indexes_count).each do |n|
        index = n * Blocks::BLOCK_CHECKPOINT_SIZE
        checkpoint = Blocks.get_checkpoint_merkle(conn, index.to_i64, BlockKind::FAST)
        conn.exec("update blocks set checkpoint = ? where idx = ?", checkpoint, index)
      end
    end
  end

  def down : String
    ""
  end
end
