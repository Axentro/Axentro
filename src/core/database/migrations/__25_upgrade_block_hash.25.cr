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
class UpgradeBlockHash < MG::Base
  include Axentro::Core
  include Data

  def up : String
    ""
  end

  def after_up(conn : DB::Connection)
    [BlockKind::SLOW, BlockKind::FAST].each do |block_kind|
      prev_block : Block? = nil
      Blocks.retrieve_blocks(conn, 0_i64, block_kind) do |block|
        if prev_block.nil?
          prev_block = block
          next
        end

        prev_block_hash = prev_block.not_nil!.to_hash
        block.prev_hash = prev_block_hash
        conn.exec("update blocks set prev_hash = '#{prev_block_hash}' where idx = ?", block.index)

        prev_block = block
      end
    end
  end

  def down : String
    ""
  end
end
