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
class CreateNoncesTable < MG::Base
  def up : String
    <<-SQL
    CREATE TABLE IF NOT EXISTS nonces (
      address          TEXT NOT NULL,
      nonce            TEXT NOT NULL,
      latest_hash      TEXT NOT NULL,
      block_id         INTEGER NOT NULL,
      difficulty       INTEGER NOT NULL,
      timestamp        INTEGER NOT NULL,
      PRIMARY KEY      (address, nonce, block_id)
      );
    SQL
  end

  def down : String
    <<-SQL
      DROP TABLE nonces;
    SQL
  end
end
