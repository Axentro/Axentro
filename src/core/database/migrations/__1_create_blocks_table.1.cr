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
class CreateBlocksTable < MG::Base
  def up : String
    <<-SQL
    CREATE TABLE IF NOT EXISTS blocks (
      idx             INTEGER PRIMARY KEY,
      nonce           TEXT NOT NULL,
      prev_hash       TEXT NOT NULL,
      timestamp       INTEGER NOT NULL,
      difficulty      INTEGER NOT NULL,
      address         TEXT NOT NULL,
      kind            TEXT NOT NULL,
      public_key      TEXT NOT NULL,
      signature       TEXT NOT NULL,
      hash            TEXT NOT NULL
      );
    SQL
  end

  def down : String
    <<-SQL
      DROP TABLE blocks;
    SQL
  end
end
