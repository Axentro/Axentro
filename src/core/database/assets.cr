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
  # ------- Definition -------

  def asset_insert_fields_string
    "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
  end

  # ------- Insert -------
  def asset_insert_values_array(b : Block, t : Transaction, asset_index : Int32) : Array(DB::Any)
    ary = [] of DB::Any
    a = t.assets[asset_index]
    ary << a.asset_id << t.id << b.index << asset_index << a.name << a.description << a.media_location << a.media_hash << a.quantity << a.terms << a.version << a.timestamp
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
        version = rows.read(Int32)
        timestamp = rows.read(Int64)
        assets << Asset.new(asset_id, name, description, media_location, media_hash, quantity, terms, version, timestamp)
      end
    end
    assets
  end

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
        version = rows.read(Int32)
        timestamp = rows.read(Int64)
        assets << Asset.new(asset_id, name, description, media_location, media_hash, quantity, terms, version, timestamp)
      end
    end
    assets
  end

  def get_latest_asset(asset_id : String) : Asset?
    assets = get_all_asset_versions(asset_id)
    assets.size > 0 ? assets.first : nil
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
        version = rows.read(Int32)
        timestamp = rows.read(Int64)
        _assets << Asset.new(asset_id, name, description, media_location, media_hash, quantity, terms, version, timestamp)
      end
    end
    _assets
  end
end
