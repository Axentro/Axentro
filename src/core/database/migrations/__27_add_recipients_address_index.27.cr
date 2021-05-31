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
class AddRecipientsAddressIndex < MG::Base
  def up : String
    <<-SQL
      CREATE INDEX IF NOT EXISTS idx_recipients_address on recipients (address);
    SQL
  end

  def down : String
    <<-SQL
      DROP INDEX idx_recipients_address;
    SQL
  end
end
