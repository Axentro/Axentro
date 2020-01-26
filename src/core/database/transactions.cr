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

module ::Sushi::Core::Data::Transactions
  # ------- Definition -------
  def transaction_table_create_string
    "id text, idx integer, block_id integer, action text, message text, token text, prev_hash text, timestamp integer, scaled integer, kind text"
  end

  def transaction_primary_key_string
    "id, idx, block_id"
  end

  def transaction_insert_fields_string
    "?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
  end

  # ------- Insert -------
  def transaction_insert_values_array(t : Transaction, transaction_idx : Int32, block_index : Int64) : Array(DB::Any)
    ary = [] of DB::Any
    ary << t.id << transaction_idx << block_index << t.action << t.message << t.token << t.prev_hash << t.timestamp << t.scaled << t.kind.to_s
  end

  # ------- Query -------
  def get_all_transactions(block_index : Int64)
    transactions_by_query(
      "select * from transactions " \
      "where block_id = ? " \
      "order by idx asc",
      block_index)
  end

  # ------- API -------
  def get_paginated_transactions(block_index : Int64, page : Int32, per_page : Int32, direction : String)
    page = page * per_page
    transactions_by_query(
      "select * from transactions " \
      "where block_id = ? " \
      "and oid not in ( select oid from transactions " \
      "order by block_id #{direction} limit ? ) " \
      "order by block_id #{direction} limit ?",
      block_index, page, per_page)
  end

  def get_paginated_transactions_for_address(address : String, page : Int32, per_page : Int32, direction : String, actions : Array(String))
    page = page * per_page
    actions = actions.map { |a| "'#{a}'" }.join(",")
    transactions_by_query(
      "select * from transactions " \
      "where id in (select transaction_id from senders " \
      "where address = '#{address}' " \
      "union select transaction_id from recipients " \
      "where address = '#{address}') " +
      (actions.empty? ? "" : "and action in (#{actions}) ") +
      "and oid not in " \
      "(select oid from transactions order by block_id #{direction} limit ? ) " \
      "order by block_id #{direction} limit ?",
      page, per_page)
  end

  def get_block_index_for_transaction(transaction_id : String) : Int64?
    idx : Int64? = nil
    @db.query("select block_id from transactions where id = ?", transaction_id) do |rows|
      rows.each do
        idx = rows.read(Int64 | Nil)
      end
    end
    idx
  end

  # ------- Helpers -------
  def transactions_by_query(query, *args)
    transactions = [] of Transaction
    verbose "Reading transactions from the database for block #{args}"
    ti = 0
    @db.query(query, args: args.to_a) do |rows|
      rows.each do
        t_id = rows.read(String)
        rows.read(Int32)
        rows.read(Int64)
        action = rows.read(String)
        message = rows.read(String)
        token = rows.read(String)
        prev_hash = rows.read(String)
        timestamp = rows.read(Int64)
        scaled = rows.read(Int32)
        kind_string = rows.read(String)
        kind = kind_string == "SLOW" ? TransactionKind::SLOW : TransactionKind::FAST

        t = Transaction.new(t_id, action, [] of Transaction::Sender, [] of Transaction::Recipient, message, token, prev_hash, timestamp, scaled, kind)
        transactions << t
        verbose "reading transaction #{ti} from database with short ID of #{t.short_id}" if ti < 4
        ti += 1
      end
    end
    transactions.each do |t|
      t.set_senders(get_senders(t))
      t.set_recipients(get_recipients(t))
    end
    transactions
  end
end
