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
class CreateIndexes < MG::Base
  def up : String
    <<-SQL
      CREATE INDEX IF NOT EXISTS idx_recipients         on recipients (transaction_id);
      CREATE INDEX IF NOT EXISTS idx_senders            on senders (transaction_id);
      CREATE INDEX IF NOT EXISTS idx_recipients_block   on recipients (block_id);
      CREATE INDEX IF NOT EXISTS idx_senders_block      on senders (block_id);
      CREATE INDEX IF NOT EXISTS idx_blocks             on blocks (timestamp);
      CREATE INDEX IF NOT EXISTS idx_blocks_kind        on blocks (kind);
      CREATE INDEX IF NOT EXISTS idx_transactions       on transactions (block_id);
    SQL
  end

  def down : String
    <<-SQL
      DROP INDEX idx_recipients;
      DROP INDEX idx_senders;
      DROP INDEX idx_recipients_block;
      DROP INDEX idx_senders_block;
      DROP INDEX idx_blocks;
      DROP INDEX idx_blocks_kind;
      DROP INDEX idx_transactions;
    SQL
  end
end
