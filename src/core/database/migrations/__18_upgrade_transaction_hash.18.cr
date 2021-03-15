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
class UpgradeTransactionHash < MG::Base
  include Axentro::Core
  include Data

  def up : String
    ""
  end

  def after_up(conn : DB::Connection)
    Blocks.retrieve_blocks(conn) do |block|
      sorted_aligned_transactions = block.transactions.select(&.is_coinbase?) + block.transactions.reject(&.is_coinbase?).sort_by(&.timestamp)
      sorted_aligned_transactions.map_with_index do |transaction, index|
        transaction.add_prev_hash((index == 0 ? "0" : sorted_aligned_transactions[index - 1].to_hash))
        if transaction.prev_hash != 0
          conn.exec("update transactions set prev_hash = '#{transaction.prev_hash}' where id = ?", transaction.id)
        end
      end
    end
  end

  def down : String
    ""
  end
end
