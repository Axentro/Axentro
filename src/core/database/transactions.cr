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
require "../dapps/build_in/scars"

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

  def get_paginated_tokens(page : Int32, per_page : Int32, direction : String)
    res = [] of String
    page = page * per_page
    @db.query(
      "select distinct(token) from transactions " \
      "where oid not in " \
      "(select oid from transactions order by token #{direction} limit ?) " \
      "order by token #{direction} limit ?",
      page, per_page) do |rows|
      rows.each { res << rows.read(String) }
    end
    res
  end

  def token_exists?(token) : Bool
    res = 0
    @db.query("select count(distinct token) from transactions where token = ?", token) do |rows|
      rows.each do
        res = rows.read(Int32)
      end
    end
    res != 0
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

  def get_domain_map_for(domain_name : String) : DomainMap
    domain_map = DomainMap.new
    @db.query(
      "select message, address, action, amount " \
      "from transactions t " \
      "join senders s on s.transaction_id = t.id " \
      "where action in ('scars_buy', 'scars_sell', 'scars_cancel') " \
      "and message = ?", domain_name) do |rows|
      rows.each do
        domain_map[domain_name] = {
          domain_name: rows.read(String),
          address:     rows.read(String),
          status:      status(rows.read(String)),
          price:       rows.read(Int64),
        }
      end
    end
    domain_map
  end

  def get_domain_map_for_address(address : String) : DomainMap
    domain_map = DomainMap.new
    @db.query(
      "select message, address, action, amount " \
      "from transactions t " \
      "join senders s on s.transaction_id = t.id " \
      "where action in ('scars_buy', 'scars_sell', 'scars_cancel') " \
      "and address = ?", address) do |rows|
      rows.each do
        domain_name = rows.read(String)
        domain_map[domain_name] = {
          domain_name: domain_name,
          address:     rows.read(String),
          status:      status(rows.read(String)),
          price:       rows.read(Int64),
        }
      end
    end
    domain_map
  end

  def get_domains_for_sale : Array(Domain)
    domain_names = [] of String
    @db.query(
      "select distinct(message) from transactions where action = 'scars_sell'") do |rows|
      rows.each do
        domain_names << rows.read(String)
      end
    end
    domain_names.map { |n| get_domain_map_for(n)[n]? }.compact
  end

  private def status(action) : Status
    case action
    when "scars_buy"
      Status::ACQUIRED
    when "scars_sell"
      Status::FOR_SALE
    else
      Status::ACQUIRED
    end
  end

  # --------- utxo -----------

  def get_address_amount(address : String) : Array(TokenQuantity)
    recipient_sum = get_recipient_sum(address)
    sender_sum = get_sender_sum(address)
    unique_tokens = (recipient_sum + sender_sum).map(&.token).push("SUSHI").uniq
    fee = get_fee_sum(address)
    unique_tokens.map do |token|
      recipient = recipient_sum.select { |r| r.token == token }.map(&.amount).sum
      sender = sender_sum.select { |s| s.token == token }.map(&.amount).sum

      if token == "SUSHI"
        sender = sender + fee
      end
      balance = recipient - sender

      TokenQuantity.new(token, balance)
    end
  end

  private def get_recipient_sum(address : String) : Array(TokenQuantity)
    token_quantity = [] of TokenQuantity
    @db.query(
      "select t.token, sum(r.amount) " \
      "from transactions t " \
      "join recipients r on r.transaction_id = t.id " \
      "where r.address = ? " \
      "group by t.token",
      address
    ) do |rows|
      rows.each do
        token = rows.read(String)
        amount = rows.read(Int64 | Nil) || 0_i64
        token_quantity << TokenQuantity.new(token, amount)
      end
    end
    token_quantity
  end

  private def get_sender_sum(address : String) : Array(TokenQuantity)
    token_quantity = [] of TokenQuantity
    @db.query(
      "select t.token, sum(s.amount) " \
      "from transactions t " \
      "join senders s on s.transaction_id = t.id " \
      "where s.address = ? " \
      "and t.action = 'send' " \
      "group by t.token",
      address
    ) do |rows|
      rows.each do
        token = rows.read(String)
        amount = rows.read(Int64 | Nil) || 0_i64
        token_quantity << TokenQuantity.new(token, amount)
      end
    end
    token_quantity
  end

  private def get_fee_sum(address : String) : Int64
    amount = 0_i64
    @db.query(
      "select sum(fee) " \
      "from senders " \
      "where address = ?",
      address
    ) do |rows|
      rows.each do
        amount = rows.read(Int64 | Nil) || 0_i64
      end
    end
    amount
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

  include Sushi::Core::DApps::BuildIn
end
