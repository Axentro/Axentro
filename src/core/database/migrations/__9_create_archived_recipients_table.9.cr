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
class CreateArchivedRecipientsTable < MG::Base
  def up : String
    <<-SQL
    CREATE TABLE IF NOT EXISTS archived_recipients (
      block_hash             TEXT NOT NULL,
      archive_timestamp      INTEGER NOT NULL,
      reason                 TEXT NOT NULL,
      transaction_id         TEXT NOT NULL,
      block_id               INTEGER NOT NULL,
      idx                    INTEGER NOT NULL,
      address                TEXT NOT NULL,
      amount                 INTEGER NOT NULL,
      PRIMARY KEY            (block_hash, idx, block_id)
      );
    SQL
  end

  def down : String
    <<-SQL
      DROP TABLE archived_recipients;
    SQL
  end
end
