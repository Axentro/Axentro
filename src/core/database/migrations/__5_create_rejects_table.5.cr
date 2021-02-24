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
class CreateRejectsTable < MG::Base
  def up : String
    <<-SQL
    CREATE TABLE IF NOT EXISTS rejects (
      transaction_id      TEXT PRIMARY KEY,
      address             TEXT NOT NULL,
      reason              TEXT NOT NULL,
      timestamp           INTEGER NOT NULL
      );
    SQL
  end

  def down : String
    <<-SQL
      DROP TABLE rejects;
    SQL
  end
end
