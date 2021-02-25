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

module ::Axentro::Core::Data::Recipients
  # ------- Definition -------
  def recipient_insert_fields_string
    "?, ?, ?, ?, ?"
  end

  # ------- Insert -------
  def recipient_insert_values_array(b : Block, t : Transaction, recipient_index : Int32) : Array(DB::Any)
    ary = [] of DB::Any
    r = t.recipients[recipient_index]
    ary << t.id << b.index << recipient_index << r[:address] << r[:amount]
  end

  # ------- Query -------
  def get_recipients(t : Transaction) : Transaction::Recipients
    recipients = [] of Transaction::Recipient
    @db.query "select * from recipients where transaction_id = ? order by idx", t.id do |rows|
      rows.each do
        rows.read(String)
        rows.read(Int64)
        rows.read(Int32)
        recipients << {
          address: rows.read(String),
          amount:  rows.read(Int64),
        }
      end
    end
    recipients
  end
end
