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
require "../blockchain/*"
require "../blockchain/domain_model/*"
require "../node/*"
require "../dapps/dapp"
require "../dapps/build_in/rejects"

module ::Axentro::Core::Data::Rejects
  # ------- Insert -------
  def insert_reject(reject : Reject)
    @db.exec("insert or ignore into rejects values (?, ?, ?, ?)", reject.transaction_id, reject.sender_address, reject.reason, reject.timestamp)
  end

  # ------- Query -------
  def find_reject(transaction_id : String) : Reject?
    rejects = [] of Reject
    @db.query("select * from rejects where transaction_id like ? || '%'", transaction_id) do |rows|
      rows.each do
        tid = rows.read(String)
        addr = rows.read(String)
        reason = rows.read(String)
        timestamp = rows.read(Int64)
        rejects << Reject.new(tid, addr, reason, timestamp)
      end
    end
    rejects.size > 0 ? rejects.first : nil
  end

  def find_reject_by_address(address : String, limit : Int32 = 5) : Array(Reject)
    rejects = [] of Reject
    @db.query("select * from rejects where address = ? order by timestamp desc limit ?", address, limit) do |rows|
      rows.each do
        tid = rows.read(String)
        addr = rows.read(String)
        reason = rows.read(String)
        timestamp = rows.read(Int64)
        rejects << Reject.new(tid, addr, reason, timestamp)
      end
    end
    rejects
  end

  def total_rejects : Int32
    @db.query_one("select count(*) from rejects", as: Int32)
  end

  def all_rejects : Array(Reject)
    rejects = [] of Reject
    @db.query("select * from rejects") do |rows|
      rows.each do
        tid = rows.read(String)
        addr = rows.read(String)
        reason = rows.read(String)
        timestamp = rows.read(Int64)
        rejects << Reject.new(tid, addr, reason, timestamp)
      end
    end
    rejects
  end

  include Axentro::Core::DApps::BuildIn
end
