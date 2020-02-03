# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.
require "../blockchain/*"
require "../blockchain/block/*"
require "../node/*"
require "../dapps/dapp"
require "../dapps/build_in/rejects"

module ::Sushi::Core::Data::Rejects
  # ------- Definition -------
  def rejects_table_create_string
    "transaction_id text, reason text"
  end

  def rejects_primary_key_string
    "transaction_id"
  end

  # ------- Insert -------
  def insert_reject(reject : Reject)
    @db.exec("insert or ignore into rejects values (?, ?)", reject.transaction_id, reject.reason)
  end

  # ------- Query -------
  def find_reject(transaction_id : String) : Reject?
    rejects = [] of Reject
    @db.query("select * from rejects where transaction_id = ?", transaction_id) do |rows|
      rows.each do
        tid = rows.read(String)
        reason = rows.read(String)
        rejects << Reject.new(tid, reason)
      end
    end
    rejects.size > 0 ? rejects.first : nil
  end

  def total_rejects : Int32
    @db.query_one("select count(*) from rejects", as: Int32)
  end

  include Sushi::Core::DApps::BuildIn
end
