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
class UpgradeMerkleRoot < MG::Base
  include Axentro::Core
  include Data

  def up : String
    ""
  end

  def after_up(conn : DB::Connection)
    Blocks.retrieve_blocks(conn) do |block|
      merkle = MerkleTreeCalculator.new(HashVersion::V2).calculate_merkle_tree_root(block.transactions)
      conn.exec("update blocks set merkle_tree_root = '#{merkle}' where idx = ?", block.index)
    end
  end

  def down : String
    ""
  end
end
