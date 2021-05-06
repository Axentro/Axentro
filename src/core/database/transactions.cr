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
require "../dapps/build_in/hra"

module ::Axentro::Core::Data::Transactions
  def internal_actions_list
    # exclude burn_token as this is used to calculate recipients sum
    DApps::UTXO_ACTIONS.reject(&.==("burn_token")).map { |action| "'#{action}'" }.uniq!.join(",")
  end

  # ------- Definition -------
  def transaction_insert_fields_string
    "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
  end

  # ------- Insert -------
  def transaction_insert_values_array(t : Transaction, transaction_idx : Int32, block_index : Int64) : Array(DB::Any)
    ary = [] of DB::Any
    ary << t.id << transaction_idx << block_index << t.action << t.message << t.token << t.prev_hash << t.timestamp << t.scaled << t.kind.to_s << t.version.to_s
  end

  # ------- Query -------
  def get_all_transactions(block_index : Int64)
    transactions_by_query(
      "select * from transactions " \
      "where block_id = ? " \
      "order by idx asc",
      block_index)
  end

  def get_transactions_for_asset(asset_id : String) : Array(AssetVersion)
    transactions = transactions_by_query("select * from transactions where id in (select transaction_id from assets where asset_id = ? order by version desc)", asset_id)
    transactions.map do |t|
      asset = t.assets.first
      address = t.action == "send_asset" ? t.recipients.map(&.address).first : t.senders.map(&.address).first
      AssetVersion.new(asset_id, t.id, asset.version, t.action, address)
    end
  end

  # ------- API -------
  def total_transactions(transaction_kind : TransactionKind) : Int32
    kind = transaction_kind == TransactionKind::SLOW ? "SLOW" : "FAST"
    @db.query_one("select count(*) from transactions where kind = ?", kind, as: Int32)
  end

  def total_transactions_for_block(block_index : Int64) : Int32
    @db.query_one("select count(*) from transactions where block_id = ?", block_index, as: Int32)
  end

  def total_transactions_for_address(address : String) : Int32
    @db.query_one(
      "select count(*) from transactions " \
      "where id in (select transaction_id from senders " \
      "where address = ? " \
      "union select transaction_id from recipients " \
      "where address = ?) ", address, address, as: Int32)
  end

  def total_transactions_size : Int32
    @db.query_one("select count(*) from transactions", as: Int32)
  end

  def get_paginated_transactions(block_index : Int64, page : Int32, per_page : Int32, direction : String, sort_field : String, actions : Array(String))
    limit = per_page
    offset = Math.max((limit * page) - limit, 0)

    actions = actions.join(",") { |a| "'#{a}'" }
    transactions_by_query(
      "select * from transactions " \
      "where block_id = ? " +
      (actions.empty? ? "" : "and action in (#{actions}) ") +
      "order by #{sort_field} #{direction} " \
      "limit ? offset ?",
      block_index, limit, offset)
  end

  def get_paginated_all_transactions(page : Int32, per_page : Int32, direction : String, sort_field : String, actions : Array(String))
    limit = per_page
    offset = Math.max((limit * page) - limit, 0)

    actions = actions.join(",") { |a| "'#{a}'" }
    transactions_by_query(
      "select * from transactions " +
      (actions.empty? ? "" : "where action in (#{actions}) ") +
      "order by #{sort_field} #{direction} " \
      "limit ? offset ?",
      limit, offset)
  end

  def get_paginated_transactions_for_address(address : String, page : Int32, per_page : Int32, direction : String, sort_field : String, actions : Array(String))
    limit = per_page
    offset = Math.max((limit * page) - limit, 0)
    actions = actions.join(",") { |a| "'#{a}'" }

    transactions_by_query(
      "select * from transactions where id in " \
      "(select transaction_id from senders where address = ? " \
      "union select transaction_id from recipients " \
      "where address = ?) " +
      (actions.empty? ? "" : "and action in (#{actions}) ") +
      "order by #{sort_field} #{direction}  " \
      "limit ? offset ?",
      address, address, limit, offset)
  end

  def get_paginated_tokens(page : Int32, per_page : Int32, direction : String)
    res = [] of String
    limit = per_page
    offset = Math.max((limit * page) - limit, 0)

    @db.query(
      "select distinct(token) from transactions " \
      "order by token #{direction} " \
      "limit ? offset ?",
      limit, offset) do |rows|
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
    @db.query("select block_id from transactions where id like ? || '%'", transaction_id) do |rows|
      rows.each do
        idx = rows.read(Int64 | Nil)
      end
    end
    idx
  end

  def get_block_index_for_asset(asset_id : String) : Int64?
    idx : Int64? = nil
    @db.query("select block_id from assets where asset_id like ? || '%'", asset_id) do |rows|
      rows.each do
        idx = rows.read(Int64?)
      end
    end
    idx
  end

  def get_domain_map_for(domain_name : String) : DomainMap
    domain_map = DomainMap.new
    @db.query(
      "select message, address, action, amount, t.block_id " \
      "from transactions t " \
      "join senders s on s.transaction_id = t.id " \
      "where action in ('hra_buy', 'hra_sell', 'hra_cancel') " \
      "and message = ?", domain_name) do |rows|
      rows.each do
        domain_map[domain_name] = {
          domain_name: rows.read(String),
          address:     rows.read(String),
          status:      status(rows.read(String)),
          price:       rows.read(Int64),
          block:       rows.read(Int64),
        }
      end
    end
    domain_map
  end

  def get_domain_map_for_address(address : String) : DomainMap
    domains = [] of String
    domain_map = DomainMap.new
    @db.query(
      "select message, address, action, amount, t.block_id " \
      "from transactions t " \
      "join senders s on s.transaction_id = t.id " \
      "where action in ('hra_buy', 'hra_sell', 'hra_cancel') " \
      "and address = ? " \
      "order by t.block_id desc", address) do |rows|
      rows.each do
        domains << rows.read(String)
      end
    end
    domain_maps = domains.uniq.map { |domain| get_domain_map_for(domain) }
    domain_maps.reduce(domain_map) { |acc, dm| acc.merge(dm) }.select { |_, d| d[:address] == address }
  end

  def get_confirmations(block_index : Int64) : Int32
    get_amount_blocks_ontop_of(block_index)
  end

  def get_domains_for_sale : Array(Domain)
    domain_names = [] of String
    @db.query(
      "select distinct(message) from transactions where action = 'hra_sell'") do |rows|
      rows.each do
        domain_names << rows.read(String)
      end
    end
    domain_names.compact_map { |n| get_domain_map_for(n)[n]? }
  end

  private def status(action) : Status
    case action
    when "hra_buy"
      Status::ACQUIRED
    when "hra_sell"
      Status::FOR_SALE
    else
      Status::ACQUIRED
    end
  end

  # --------- utxo -----------

  def get_address_amounts(addresses : Array(String)) : Hash(String, Array(TokenQuantity))
    addresses.uniq!
    amounts_per_address : Hash(String, Array(TokenQuantity)) = {} of String => Array(TokenQuantity)
    addresses.each { |a| amounts_per_address[a] = [] of TokenQuantity }

    recipient_sum_per_address = get_recipient_sum_per_address(addresses)
    sender_sum_per_address = get_sender_sum_per_address(addresses)
    fee_sum_per_address = get_fee_sum_per_address(addresses)
    burned_sum_per_address = get_burned_token_sum_per_address(addresses)

    addresses.each do |address|
      recipient_sum = recipient_sum_per_address[address]
      sender_sum = sender_sum_per_address[address]
      burned_sum = burned_sum_per_address[address]
      unique_tokens = (recipient_sum + sender_sum + burned_sum).map(&.token).push("AXNT").uniq

      unique_tokens.map do |token|
        recipient = recipient_sum.select(&.token.==(token)).sum(&.amount)
        sender = sender_sum.select(&.token.==(token)).sum(&.amount)
        burned = burned_sum.select(&.token.==(token)).sum(&.amount)
        fee = fee_sum_per_address[address]

        if token == "AXNT"
          sender = sender + fee
        end
        balance = recipient - (sender + burned)

        amounts_per_address[address] << TokenQuantity.new(token, balance)
      end
    end

    amounts_per_address
  end

  def get_address_amount(address : String) : Array(TokenQuantity)
    recipient_sum = get_recipient_sum(address)
    sender_sum = get_sender_sum(address)
    burned_sum = get_burned_token_sum(address)
    unique_tokens = (recipient_sum + sender_sum + burned_sum).map(&.token).push("AXNT").uniq
    fee = get_fee_sum(address)
    unique_tokens.map do |token|
      recipient = recipient_sum.select(&.token.==(token)).sum(&.amount)
      sender = sender_sum.select(&.token.==(token)).sum(&.amount)
      burned = burned_sum.select(&.token.==(token)).sum(&.amount)

      if token == "AXNT"
        sender = sender + fee
      end

      balance = recipient - (sender + burned)

      TokenQuantity.new(token, balance)
    end
  end

  def get_amount_confirmation(address : String) : Int32
    block = nil
    @db.query("select max(block_id) from recipients where address = ?", address) do |rows|
      rows.each do
        block = rows.read(Int64 | Nil)
      end
    end
    if block
      get_confirmations(block.not_nil!)
    else
      0
    end
  end

  private def get_recipient_sum(address : String) : Array(TokenQuantity)
    token_quantity = [] of TokenQuantity
    @db.query(
      "select t.token, sum(r.amount) " \
      "from transactions t " \
      "join recipients r on r.transaction_id = t.id " \
      "where r.address = ? " \
      "and t.action in (#{internal_actions_list}) " \
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

  private def get_recipient_sum_per_address(addresses : Array(String)) : Hash(String, Array(TokenQuantity))
    amounts_per_address : Hash(String, Array(TokenQuantity)) = {} of String => Array(TokenQuantity)
    addresses.uniq.each { |a| amounts_per_address[a] = [] of TokenQuantity }
    address_list = addresses.map { |a| "'#{a}'" }.uniq!.join(",")
    @db.query(
      "select r.address, t.token, sum(r.amount) as 'rec' from transactions t " \
      "join recipients r on r.transaction_id = t.id " \
      "where r.address in (#{address_list}) " \
      "and t.action in (#{internal_actions_list}) " \
      "group by r.address, t.token") do |rows|
      rows.each do
        address = rows.read(String)
        token = rows.read(String)
        amount = rows.read(Int64 | Nil) || 0_i64
        amounts_per_address[address] << TokenQuantity.new(token, amount)
      end
    end
    amounts_per_address
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

  private def get_sender_sum_per_address(addresses : Array(String)) : Hash(String, Array(TokenQuantity))
    amounts_per_address : Hash(String, Array(TokenQuantity)) = {} of String => Array(TokenQuantity)
    addresses.uniq.each { |a| amounts_per_address[a] = [] of TokenQuantity }
    address_list = addresses.map { |a| "'#{a}'" }.uniq!.join(",")
    @db.query(
      "select s.address, t.token, sum(s.amount) as 'send' from transactions t " \
      "join senders s on s.transaction_id = t.id " \
      "where s.address in (#{address_list}) " \
      "and t.action = 'send' " \
      "group by s.address, t.token") do |rows|
      rows.each do
        address = rows.read(String)
        token = rows.read(String)
        amount = rows.read(Int64 | Nil) || 0_i64
        amounts_per_address[address] << TokenQuantity.new(token, amount)
      end
    end
    amounts_per_address
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

  private def get_fee_sum_per_address(addresses : Array(String)) : Hash(String, Int64)
    amounts_per_address : Hash(String, Int64) = {} of String => Int64
    addresses.uniq.each { |a| amounts_per_address[a] = 0_i64 }
    address_list = addresses.map { |a| "'#{a}'" }.uniq!.join(",")
    @db.query(
      "select address, sum(fee) as 'fee' " \
      "from senders " \
      "where address in (#{address_list})"
    ) do |rows|
      rows.each do
        address = rows.read(String | Nil) || "no-address"
        fee = rows.read(Int64 | Nil) || 0_i64
        amounts_per_address[address] = fee
      end
    end
    amounts_per_address
  end

  private def get_burned_token_sum(address : String) : Array(TokenQuantity)
    token_quantity = [] of TokenQuantity
    @db.query(
      "select t.token, sum(r.amount) " \
      "from transactions t " \
      "join recipients r on r.transaction_id = t.id " \
      "where address = ? " \
      "and t.action = 'burn_token' " \
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

  private def get_burned_token_sum_per_address(addresses : Array(String)) : Hash(String, Array(TokenQuantity))
    amounts_per_address : Hash(String, Array(TokenQuantity)) = {} of String => Array(TokenQuantity)
    addresses.uniq.each { |a| amounts_per_address[a] = [] of TokenQuantity }
    address_list = addresses.map { |a| "'#{a}'" }.uniq!.join(",")
    @db.query(
      "select r.address, t.token, sum(r.amount) as 'burn' " \
      "from transactions t " \
      "join recipients r on r.transaction_id = t.id " \
      "where r.address in (#{address_list}) " \
      "and t.action = 'burn_token' " \
      "group by t.token"
    ) do |rows|
      rows.each do
        address = rows.read(String)
        token = rows.read(String)
        amount = rows.read(Int64 | Nil) || 0_i64
        amounts_per_address[address] << TokenQuantity.new(token, amount)
      end
    end
    amounts_per_address
  end

  # ------- Indices -------
  def get_transactions_and_block_that_exist(transactions : Array(Transaction)) : Array(TransactionWithBlock)
    transaction_list = transactions.map { |t| "'#{t.id}'" }.uniq!.join(",")
    transaction_ids = {} of String => Int64
    @db.query(
      "select id, block_id from transactions " \
      "where id in (#{transaction_list})"
    ) do |rows|
      rows.each do
        transaction_id = rows.read(String)
        block_id = rows.read(Int64)
        transaction_ids[transaction_id] = block_id
      end
    end

    transactions.select { |t| transaction_ids.keys.includes?(t.id) }.map do |transaction|
      block = transaction_ids[transaction.id]
      TransactionWithBlock.new(transaction, block)
    end
  end

  # ------- Official nodes -------
  def get_official_nodes : OfficialNodesConfig
    official_nodes_config = {"slownodes" => [] of String, "fastnodes" => [] of String}
    @db.query(
      "select r.address, t.action " \
      "from transactions t " \
      "join recipients r on r.transaction_id = t.id " \
      "where action in ( 'create_official_node_slow', 'create_official_node_fast') "
    ) do |rows|
      rows.each do
        address = rows.read(String)
        action = rows.read(String)
        if action == "create_official_node_slow"
          official_nodes_config["slownodes"] << address
        elsif action == "create_official_node_fast"
          official_nodes_config["fastnodes"] << address
        end
      end
    end
    official_nodes_config
  end

  # ------- Tokens -------
  def token_info(unique_tokens : Array(String)) : Hash(String, DApps::BuildIn::TokenInfo)
    token_list = unique_tokens.map { |t| "'#{t}'" }.uniq!.join(",")
    token_map = {} of String => DApps::BuildIn::TokenInfo
    @db.query(
      "select t.token, r.address, t.action " \
      "from transactions t " \
      "join recipients r on r.transaction_id = t.id " \
      "where t.token in (#{token_list}) " \
      "and t.action in ('create_token','lock_token')"
    ) do |rows|
      rows.each do
        token = rows.read(String)
        address = rows.read(String)
        action = rows.read(String)
        token_map[token] = DApps::BuildIn::TokenInfo.new(address, action == "lock_token")
      end
    end
    token_map
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
        version_string = rows.read(String)
        version = TransactionVersion.parse(version_string)

        t = Transaction.new(t_id, action, [] of Transaction::Sender, [] of Transaction::Recipient, [] of Transaction::Asset, [] of Transaction::Module, [] of Transaction::Input, [] of Transaction::Output, "", message, token, prev_hash, timestamp, scaled, kind, version)
        transactions << t
        verbose "reading transaction #{ti} from database with short ID of #{t.short_id}" if ti < 4
        ti += 1
      end
    end
    transactions.each do |t|
      t.set_senders(get_senders(t))
      t.set_recipients(get_recipients(t))
      t.set_assets(get_assets(t))
    end
    transactions
  end

  include Axentro::Core::DApps::BuildIn
end
