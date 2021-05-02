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

module ::Axentro::Core::Data::Assets
  def internal_asset_actions_list
    DApps::ASSET_ACTIONS.map { |action| "'#{action}'" }.uniq!.join(",")
  end

  # ------- Definition -------

  def asset_insert_fields_string
    "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
  end

  # ------- Insert -------
  def asset_insert_values_array(b : Block, t : Transaction, asset_index : Int32) : Array(DB::Any)
    ary = [] of DB::Any
    a = t.assets[asset_index]
    ary << a.asset_id << t.id << b.index << asset_index << a.name << a.description << a.media_location << a.media_hash << a.quantity << a.terms << a.locked.to_s << a.version << a.timestamp
  end

  # ------- Query -------
  def get_assets(t : Transaction) : Transaction::Assets
    assets = [] of Transaction::Asset
    @db.query "select * from assets where transaction_id = ? order by idx", t.id do |rows|
      rows.each do
        asset_id = rows.read(String)
        rows.read(String)
        rows.read(Int64)
        rows.read(Int32)
        name = rows.read(String)
        description = rows.read(String)
        media_location = rows.read(String)
        media_hash = rows.read(String)
        quantity = rows.read(Int32)
        terms = rows.read(String)
        locked = AssetAccess.parse(rows.read(String))
        version = rows.read(Int32)
        timestamp = rows.read(Int64)
        assets << Asset.new(asset_id, name, description, media_location, media_hash, quantity, terms, locked, version, timestamp)
      end
    end
    assets
  end

  # ------- asset utxo -------

  def get_address_asset_amounts(addresses : Array(String)) : Hash(String, Array(AssetQuantity))
    addresses.uniq!
    amounts_per_address : Hash(String, Array(AssetQuantity)) = {} of String => Array(AssetQuantity)
    addresses.each { |a| amounts_per_address[a] = [] of AssetQuantity }

    recipient_sum_per_address = get_asset_recipient_sum_per_address(addresses)
    sender_sum_per_address = get_asset_sender_sum_per_address(addresses)
    create_update_sum_per_address = get_asset_create_update_sum_per_address(addresses)

    addresses.each do |address|
      recipient_sum = recipient_sum_per_address[address]
      sender_sum = sender_sum_per_address[address]
      create_update_sum = create_update_sum_per_address[address]
      unique_asset_ids = (recipient_sum + sender_sum + create_update_sum).map(&.asset_id).uniq!

      unique_asset_ids.map do |asset_id|
        recipient = recipient_sum.select(&.asset_id.==(asset_id)).sum(&.quantity)
        sender = sender_sum.select(&.asset_id.==(asset_id)).sum(&.quantity)
        create_update = create_update_sum.select(&.asset_id.==(asset_id)).sum(&.quantity)

        balance = (create_update + recipient) - sender

        amounts_per_address[address] << AssetQuantity.new(asset_id, balance)
      end
    end

    amounts_per_address
  end

  private def get_asset_recipient_sum_per_address(addresses : Array(String)) : Hash(String, Array(AssetQuantity))
    amounts_per_address : Hash(String, Array(AssetQuantity)) = {} of String => Array(AssetQuantity)
    addresses.uniq.each { |a| amounts_per_address[a] = [] of AssetQuantity }
    address_list = addresses.map { |a| "'#{a}'" }.uniq!.join(",")
    @db.query(
      "select r.address, r.asset_id, sum(r.asset_quantity) as 'rec' from transactions t " \
      "join recipients r on r.transaction_id = t.id " \
      "where r.address in (#{address_list}) " \
      "and t.action in (#{internal_asset_actions_list}) " \
      "group by r.address, r.asset_id") do |rows|
      rows.each do
        address = rows.read(String)
        asset_id = rows.read(String?)
        next unless asset_id
        quantity = rows.read(Int32?) || 0
        amounts_per_address[address] << AssetQuantity.new(asset_id.not_nil!, quantity)
      end
    end
    amounts_per_address
  end

  private def get_asset_sender_sum_per_address(addresses : Array(String)) : Hash(String, Array(AssetQuantity))
    amounts_per_address : Hash(String, Array(AssetQuantity)) = {} of String => Array(AssetQuantity)
    addresses.uniq.each { |a| amounts_per_address[a] = [] of AssetQuantity }
    address_list = addresses.map { |a| "'#{a}'" }.uniq!.join(",")
    @db.query(
      "select s.address, s.asset_id, sum(s.asset_quantity) as 'send' from transactions t " \
      "join senders s on s.transaction_id = t.id " \
      "where s.address in (#{address_list}) " \
      "and t.action = 'send_asset' " \
      "group by s.address, s.asset_id") do |rows|
      rows.each do
        address = rows.read(String)
        asset_id = rows.read(String?)
        next unless asset_id
        quantity = rows.read(Int32?) || 0
        amounts_per_address[address] << AssetQuantity.new(asset_id.not_nil!, quantity)
      end
    end
    amounts_per_address
  end

  struct AssetVersionQuantity
    property asset_id : String
    property address : String
    property quantity : Int32
    property version : Int32

    def initialize(@asset_id, @address, @quantity, @version); end
  end

  # find quantity for latest asset_version where either create or update action
  private def get_asset_create_update_sum_per_address(addresses : Array(String)) : Hash(String, Array(AssetQuantity))
    amounts_per_address : Hash(String, Array(AssetQuantity)) = {} of String => Array(AssetQuantity)
    addresses.uniq.each { |a| amounts_per_address[a] = [] of AssetQuantity }
    address_list = addresses.map { |a| "'#{a}'" }.uniq!.join(",")
    asset_versions = [] of AssetVersionQuantity

    @db.query(
      "select s.address, a.asset_id, a.quantity, a.version from transactions t " \
      "join assets a on a.transaction_id = t.id " \
      "join senders s on s.transaction_id = t.id " \
      "where s.address in (#{address_list}) " \
      "and t.action in ('create_asset', 'update_asset') ") do |rows|
      rows.each do
        address = rows.read(String)
        asset_id = rows.read(String)
        asset_quantity = rows.read(Int32?) || 0
        asset_version = rows.read(Int32)
        asset_versions << AssetVersionQuantity.new(asset_id.not_nil!, address, asset_quantity, asset_version)
      end
    end

    asset_versions.group_by(&.asset_id).flat_map { |_, avs| avs.select(&.version.==(avs.map(&.version).max)) }.each do |asset_version|
      amounts_per_address[asset_version.address] << AssetQuantity.new(asset_version.asset_id, asset_version.quantity)
    end

    amounts_per_address
  end

  # ----------------

  def get_all_asset_versions(asset_id : String) : Array(Asset)
    assets = [] of Transaction::Asset
    @db.query("select * from assets where asset_id = ? order by version desc", asset_id) do |rows|
      rows.each do
        asset_id = rows.read(String)
        rows.read(String)
        rows.read(Int64)
        rows.read(Int32)
        name = rows.read(String)
        description = rows.read(String)
        media_location = rows.read(String)
        media_hash = rows.read(String)
        quantity = rows.read(Int32)
        terms = rows.read(String)
        locked = AssetAccess.parse(asset_rows.read(String))
        version = rows.read(Int32)
        timestamp = rows.read(Int64)
        assets << Asset.new(asset_id, name, description, media_location, media_hash, quantity, terms, locked, version, timestamp)
      end
    end
    assets
  end

  def get_latest_asset(asset_id : String) : Asset?
    assets = get_all_asset_versions(asset_id)
    assets.size > 0 ? assets.first : nil
  end

  def existing_assets_from_sender(asset_ids : Array(String)) : Array(Asset)
    _assets = [] of Transaction::Asset
    asset_list = asset_ids.map { |a| "'#{a}'" }.uniq!.join(",")
    @db.query("select * from assets where asset_id in (#{asset_list})") do |rows|
      rows.each do
        asset_id = rows.read(String)
        rows.read(String)
        rows.read(Int64)
        rows.read(Int32)
        name = rows.read(String)
        description = rows.read(String)
        media_location = rows.read(String)
        media_hash = rows.read(String)
        quantity = rows.read(Int32)
        terms = rows.read(String)
        locked = AssetAccess.parse(rows.read(String))
        version = rows.read(Int32)
        timestamp = rows.read(Int64)
        _assets << Asset.new(asset_id, name, description, media_location, media_hash, quantity, terms, locked, version, timestamp)
      end
    end
    _assets.group_by(&.asset_id).flat_map { |_, assets| assets.select(&.version.==(assets.map(&.version).max)) }
  end

  # based on asset_id, media_location and media_hash
  def existing_assets_from(assets : Array(Asset)) : Array(Asset)
    _assets = [] of Transaction::Asset
    asset_list = assets.map { |a| "'#{a.asset_id}'" }.uniq!.join(",")
    media_locations = assets.map { |a| "'#{a.media_location}'" }.uniq!.join(",")
    media_hashes = assets.map { |a| "'#{a.media_hash}'" }.uniq!.join(",")

    @db.query "select * from assets where asset_id in (#{asset_list}) or media_location in (#{media_locations}) or media_hash in (#{media_hashes}) order by idx" do |rows|
      rows.each do
        asset_id = rows.read(String)
        rows.read(String)
        rows.read(Int64)
        rows.read(Int32)
        name = rows.read(String)
        description = rows.read(String)
        media_location = rows.read(String)
        media_hash = rows.read(String)
        quantity = rows.read(Int32)
        terms = rows.read(String)
        locked = AssetAccess.parse(rows.read(String))
        version = rows.read(Int32)
        timestamp = rows.read(Int64)
        _assets << Asset.new(asset_id, name, description, media_location, media_hash, quantity, terms, locked, version, timestamp)
      end
    end
    _assets.group_by(&.asset_id).flat_map { |_, ass| ass.select(&.version.==(ass.map(&.version).max)) }
  end
end
