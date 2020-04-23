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

module ::Sushi::Core::Data::Senders
  # ------- Definition -------
  def sender_table_create_string
    "transaction_id text, block_id integer, idx integer, address text, public_key text, amount integer, fee integer, signature text"
  end

  def sender_primary_key_string
    "transaction_id, block_id, idx"
  end

  def sender_insert_fields_string
    "?, ?, ?, ?, ?, ?, ?, ?"
  end

  # ------- Insert -------
  def sender_insert_values_array(b : Block, t : Transaction, sender_index : Int32) : Array(DB::Any)
    ary = [] of DB::Any
    s = t.senders[sender_index]
    ary << t.id << b.index << sender_index << s[:address] << s[:public_key] << s[:amount] << s[:fee] << s[:signature]
  end

  # ------- Query -------
  def get_senders(t : Transaction) : Transaction::Senders
    senders = [] of Transaction::Sender
    @db.query "select * from senders where transaction_id = ? order by idx", t.id do |rows|
      rows.each do
        rows.read(String?)
        rows.read(Int64)
        rows.read(Int32)
        senders << {
          address:    rows.read(String),
          public_key: rows.read(String),
          amount:     rows.read(Int64),
          fee:        rows.read(Int64),
          signature:  rows.read(String),
        }
      end
    end
    senders
  end
end
