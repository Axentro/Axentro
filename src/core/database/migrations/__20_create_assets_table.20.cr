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
class CreateAssetsTable < MG::Base
  def up : String
    <<-SQL
    CREATE TABLE IF NOT EXISTS assets (
      asset_id            TEXT NOT NULL,
      transaction_id      TEXT NOT NULL,
      block_id            INTEGER NOT NULL,
      idx                 INTEGER NOT NULL,
      name                TEXT NOT NULL,
      description         TEXT NOT NULL,
      media_location      TEXT NOT NULL,
      media_hash          TEXT NOT NULL,
      quantity            INTEGER NOT NULL,
      terms               TEXT NOT NULL,
      locked              INTEGER NOT NULL,
      version             INTEGER NOT NULL,
      timestamp           INTEGER NOT NULL,
      PRIMARY KEY         (asset_id, version)
      );
    SQL
  end

  def down : String
    <<-SQL
      DROP TABLE assets;
    SQL
  end
end
