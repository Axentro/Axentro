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

module ::Axentro::Core::DApps::BuildIn
  class AssetVersion
    property asset_id : String
    property transaction_id : String
    property version : Int32
    property action : String
    property address : String

    def initialize(@asset_id, @transaction_id, @version, @action, @address); end
  end

  class AssetComponent < DApp
    def setup
    end

    def transaction_actions : Array(String)
      ASSET_ACTIONS
    end

    def transaction_related?(action : String) : Bool
      transaction_actions.includes?(action)
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      vt = ValidatedTransactions.empty

      processed_transactions = transactions.select(&.is_coinbase?)
      body_transactions = transactions.reject(&.is_coinbase?)

      existing_assets = database.existing_assets_from(body_transactions.flat_map(&.assets))

      body_transactions.each do |transaction|
        token = transaction.token
        action = transaction.action

        # common rules for transaction asset level
        raise "senders can only be 1 for asset action" if transaction.senders.size != 1
        raise "number of specified senders must be 1 for '#{action}'" if transaction.senders.size != 1
        raise "number of specified recipients must be 1 for '#{action}'" if transaction.recipients.size != 1
        raise "token must not be empty" if token.empty?

        sender = transaction.senders[0]
        sender_address = sender.address
        sender_amount = sender.amount

        recipient = transaction.recipients[0]
        recipient_address = recipient.address
        recipient_amount = recipient.amount

        raise "address mismatch for '#{action}'. " +
              "sender: #{sender_address}, recipient: #{recipient_address}" if sender_address != recipient_address

        raise "amount mismatch for '#{action}'. " +
              "sender: #{sender_amount}, recipient: #{recipient_amount}" if sender_amount != recipient_amount

        raise "amount must be 0 for action: #{action}" if (sender_amount != 0_i64 || recipient_amount != 0_i64)

        if ["create_asset", "update_asset"].includes?(action)
          raise "a transaction must have exactly 1 asset for '#{action}'" if transaction.assets.size != 1
          asset = transaction.assets.first
          raise "asset_id must be length of 64 for '#{action}'" if asset.asset_id.size != 64
          raise "asset quantity must be 1 or more for '#{action}' with asset_id: #{asset.asset_id}" if asset.quantity <= 0
        end

        if action == "create_asset"
          asset = transaction.assets.first
          raise "asset version must be 1 for '#{action}'" if asset.version != 1
          raise "asset locked must be 0 for '#{action}'" if asset.locked != 0

          asset_id_exists_in_db = existing_assets.find(&.asset_id.==(asset.asset_id))
          asset_id_exists_in_transactions = processed_transactions.find { |t| t.action == "create_asset" && t.assets.map(&.asset_id).includes?(asset.asset_id) }
          raise "asset_id must not already exist (asset_id: #{asset.asset_id}) '#{action}'" if asset_id_exists_in_db || asset_id_exists_in_transactions

          if !asset.media_location.empty?
            asset_media_location_exists_in_db = existing_assets.find(&.media_location.==(asset.media_location))
            asset_media_location_exists_in_transactions = processed_transactions.find { |t| t.action == "create_asset" && t.assets.map(&.media_location).includes?(asset.media_location) }
            raise "asset media_location must not already exist (asset_id: #{asset.asset_id}, media_location: #{asset.media_location}) '#{action}'" if asset_media_location_exists_in_db || asset_media_location_exists_in_transactions
          end

          if !asset.media_hash.empty?
            asset_media_hash_exists_in_db = existing_assets.find(&.media_hash.==(asset.media_hash))
            asset_media_hash_exists_in_transactions = processed_transactions.find { |t| t.action == "create_asset" && t.assets.map(&.media_hash).includes?(asset.media_hash) }
            raise "asset media_hash must not already exist (asset_id: #{asset.asset_id}, media_hash: #{asset.media_hash}) '#{action}'" if asset_media_hash_exists_in_db || asset_media_hash_exists_in_transactions
          end
        end

        if action == "update_asset"
          asset = transaction.assets.first

          asset_id_exists_in_db = existing_assets.find(&.asset_id.==(asset.asset_id))
          asset_id_exists_in_transactions = processed_transactions.find(&.assets.map(&.asset_id).includes?(asset.asset_id))
          raise "cannot #{action.split("_").join(" ")} with asset_id: #{asset.asset_id} as asset with this id is not found" unless asset_id_exists_in_db || asset_id_exists_in_transactions

          latest_assets = (existing_assets + processed_transactions.flat_map(&.assets)).select(&.asset_id.==(asset.asset_id)).sort_by!(&.version)
          latest_asset = latest_assets.size > 0 ? latest_assets.last : nil

          if latest_asset
            next_asset_version = latest_asset.version + 1
            raise "expected asset version #{next_asset_version} not #{asset.version} as next in sequence for '#{action}'" if asset.version != next_asset_version
            raise "asset is locked so no updates are possible for '#{action}'" if latest_asset.locked != 0
          end

          db_asset_versions = database.get_transactions_for_asset(asset.asset_id)

          txn_asset_versions = processed_transactions.select { |t| t.assets.map(&.asset_id).includes?(asset.asset_id) }.map do |t|
            asset = t.assets.first
            address = t.action == "send_asset" ? t.recipients.map(&.address).first : t.senders.map(&.address).first
            AssetVersion.new(asset.asset_id, t.id, asset.version, t.action, address)
          end

          all_asset_versions = (db_asset_versions + txn_asset_versions)

          asset_owner = all_asset_versions.sort_by(&.version).last.address
          sender_address = transaction.senders.map(&.address).last
          raise "cannot update asset with asset_id: #{asset.asset_id} as sender with address #{sender_address} does not own this asset (owned by: #{asset_owner})" if sender_address != asset_owner

          if !asset.media_location.empty?
            asset_media_location_exists_in_db = existing_assets.reject(&.asset_id.==(asset.asset_id)).find(&.media_location.==(asset.media_location))
            asset_media_location_exists_in_transactions = processed_transactions.find { |t| t.assets.reject(&.asset_id.==(asset.asset_id)).map(&.media_location).includes?(asset.media_location) }
            raise "asset media_location must not already exist (asset_id: #{asset.asset_id}, media_location: #{asset.media_location}) '#{action}'" if asset_media_location_exists_in_db || asset_media_location_exists_in_transactions
          end

          if !asset.media_hash.empty?
            asset_media_hash_exists_in_db = existing_assets.reject(&.asset_id.==(asset.asset_id)).find(&.media_hash.==(asset.media_hash))
            asset_media_hash_exists_in_transactions = processed_transactions.find { |t| t.assets.reject(&.asset_id.==(asset.asset_id)).map(&.media_hash).includes?(asset.media_hash) }
            raise "asset media_hash must not already exist (asset_id: #{asset.asset_id}, media_hash: #{asset.media_hash}) '#{action}'" if asset_media_hash_exists_in_db || asset_media_hash_exists_in_transactions
          end
        end

        vt << transaction
        processed_transactions << transaction
      rescue e : Exception
        vt << FailedTransaction.new(transaction, e.message || "unknown error")
      end
      vt
    end

    def self.fee(action : String) : Int64
      0_i64
    end

    def record(chain : Blockchain::Chain)
    end

    def clear
    end

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
    end

    def on_message(action : String, from_address : String, content : String, from = nil) : Bool
      false
    end
  end
end
