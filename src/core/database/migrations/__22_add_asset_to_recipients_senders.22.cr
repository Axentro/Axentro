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
class AddAssetToRecipientsSenders < MG::Base
  def up : String
    <<-SQL
    ALTER TABLE senders             ADD COLUMN asset_id       TEXT    DEFAULT NULL;
    ALTER TABLE senders             ADD COLUMN asset_quantity INTEGER DEFAULT NULL;
    ALTER TABLE recipients          ADD COLUMN asset_id       TEXT    DEFAULT NULL;
    ALTER TABLE recipients          ADD COLUMN asset_quantity INTEGER DEFAULT NULL;
    ALTER TABLE archived_senders    ADD COLUMN asset_id       TEXT    DEFAULT NULL;
    ALTER TABLE archived_senders    ADD COLUMN asset_quantity INTEGER DEFAULT NULL;
    ALTER TABLE archived_recipients ADD COLUMN asset_id       TEXT    DEFAULT NULL;
    ALTER TABLE archived_recipients ADD COLUMN asset_quantity INTEGER DEFAULT NULL;
  SQL
  end

  def down : String
    ""
  end
end
