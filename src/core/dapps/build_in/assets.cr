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

  class AssetQuantity
    property asset_id : String
    property quantity : Int32

    def initialize(@asset_id, @quantity); end
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

      existing_sender_assets = database.existing_assets_from_sender(body_transactions.flat_map(&.senders.compact_map(&.asset_id)))
      existing_assets = database.existing_assets_from(body_transactions.flat_map(&.assets) + existing_sender_assets)

      existing_quantities_per_asset = database.get_address_asset_amounts(body_transactions.flat_map(&.senders.map(&.address)))

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

        raise "amount must be 0 for action: #{action}" if (sender_amount != 0_i64 || recipient_amount != 0_i64)

        if ["create_asset", "update_asset"].includes?(action)
          raise "address mismatch for '#{action}'. " +
                "sender: #{sender_address}, recipient: #{recipient_address}" if sender_address != recipient_address

          raise "amount mismatch for '#{action}'. " +
                "sender: #{sender_amount}, recipient: #{recipient_amount}" if sender_amount != recipient_amount

          raise "a transaction must have exactly 1 asset for '#{action}'" if transaction.assets.size != 1
          asset = transaction.assets.first
          raise "asset_id must be length of 64 for '#{action}'" if asset.asset_id.size != 64
          raise "asset quantity must be 1 or more for '#{action}' with asset_id: #{asset.asset_id}" if asset.quantity <= 0

          if !asset.media_location.empty?
            asset_media_location_exists_in_db = existing_assets.reject(&.asset_id.==(asset.asset_id)).find(&.media_location.==(asset.media_location))
            asset_media_location_exists_in_transactions = processed_transactions.find { |t| t.assets.reject(&.asset_id.==(asset.asset_id)).map(&.media_location).includes?(asset.media_location) }
            if asset_media_location_exists_in_db || asset_media_location_exists_in_transactions
              raise "asset media_location must not already exist (asset_id: #{asset.asset_id}, media_location: #{asset.media_location}) '#{action}'"
            end
          end

          if !asset.media_hash.empty?
            asset_media_hash_exists_in_db = existing_assets.reject(&.asset_id.==(asset.asset_id)).find(&.media_hash.==(asset.media_hash))
            asset_media_hash_exists_in_transactions = processed_transactions.find { |t| t.assets.reject(&.asset_id.==(asset.asset_id)).map(&.media_hash).includes?(asset.media_hash) }
            if asset_media_hash_exists_in_db || asset_media_hash_exists_in_transactions
              raise "asset media_hash must not already exist (asset_id: #{asset.asset_id}, media_hash: #{asset.media_hash}) '#{action}'"
            end
          end
        end

        if action == "create_asset"
          asset = transaction.assets.first
          raise "asset version must be 1 for '#{action}'" if asset.version != 1
          raise "asset must be either locked or unlocked for '#{action}'" unless [AssetAccess::UNLOCKED, AssetAccess::LOCKED].includes?(asset.locked)

          asset_id_exists_in_db = existing_assets.find(&.asset_id.==(asset.asset_id))
          asset_id_exists_in_transactions = processed_transactions.find { |t| t.action == "create_asset" && t.assets.map(&.asset_id).includes?(asset.asset_id) }
          if asset_id_exists_in_db || asset_id_exists_in_transactions
            raise "asset_id must not already exist (asset_id: #{asset.asset_id}) '#{action}'"
          end
        elsif action == "update_asset"
          asset = transaction.assets.first

          asset_id_exists_in_db = existing_assets.find(&.asset_id.==(asset.asset_id))
          asset_id_exists_in_transactions = processed_transactions.find(&.assets.map(&.asset_id).includes?(asset.asset_id))
          raise "cannot #{action.split("_").join(" ")} with asset_id: #{asset.asset_id} as asset with this id is not found" unless asset_id_exists_in_db || asset_id_exists_in_transactions

          latest_assets = (existing_assets + processed_transactions.flat_map(&.assets)).select(&.asset_id.==(asset.asset_id)).sort_by!(&.version)
          latest_asset = latest_assets.size > 0 ? latest_assets.last : nil

          if latest_asset
            next_asset_version = latest_asset.version + 1
            raise "expected asset version #{next_asset_version} not #{asset.version} as next in sequence for '#{action}'" if asset.version != next_asset_version
            raise "asset is locked so no updates are possible for '#{action}'" if latest_asset.locked != AssetAccess::UNLOCKED
          end

          # asset ownership
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
        elsif action == "send_asset"
          # asset should be empty for send
          if transaction.assets.size != 0
            raise "The assets should be empty in the transaction for action: send_asset"
          end

          # senders and recipient asset_id should not be nil
          if sender.asset_id.nil? || recipient.asset_id.nil?
            raise "asset_id must be supplied for both sender and recipient in order to send an asset"
          end

          sender_asset_id = sender.asset_id.not_nil!
          recipient_asset_id = recipient.asset_id.not_nil!

          # sender and recipient asset_id should be the same
          if sender_asset_id != recipient_asset_id
            raise "asset_id must be the same for both sender and recipient in order to send an asset"
          end

          # sender and recipient asset_quantity should not be nil
          if sender.asset_quantity.nil? || recipient.asset_quantity.nil?
            raise "asset_quantity must be 1 or more for both sender and recipient in order to send an asset (was nil)"
          end

          sender_asset_quantity = sender.asset_quantity.not_nil!
          recipient_asset_quantity = recipient.asset_quantity.not_nil!

          # sender and recipients asset_quantity should be 1 or more
          if sender_asset_quantity < 1 || recipient_asset_quantity < 1
            raise "asset_quantity must be 1 or more for both sender and recipient in order to send an asset"
          end

          # sender and recipient asset_quantity should be the same
          if sender_asset_quantity != recipient_asset_quantity
            raise "asset_quantity must be the same for both sender and recipient in order to send an asset"
          end

          latest_assets = (existing_assets + processed_transactions.flat_map(&.assets)).select(&.asset_id.==(sender_asset_id)).sort_by!(&.version)
          latest_asset = latest_assets.size > 0 ? latest_assets.last : nil

          if latest_asset
            raise "asset must be locked in order to send asset #{sender_asset_id}" if latest_asset.locked != AssetAccess::LOCKED
          end

          all_addresses = processed_transactions.flat_map(&.senders.map(&.address))
          processed_asset_quantities = processed_quantities_per_asset(all_addresses, processed_transactions)
          all_asset_quantities = existing_quantities_per_asset.merge(processed_asset_quantities) { |_, xs, ys| (xs + ys).uniq! }

          # pp existing_quantities_per_asset
          # pp processed_asset_quantities
          # pp all_asset_quantities

          if has_assets = all_asset_quantities[sender_address]?
            if has_assets.size <= 0
              raise "you have 0 quantity of asset: #{sender_asset_id} so you cannot send #{sender_asset_quantity}"
            elsif has_assets.find(&.asset_id.==(sender_asset_id))
              # sender has a quantity of the asset they are attempting to send
              target_asset = has_assets.find(&.asset_id.==(sender_asset_id))
              if target_asset.not_nil!.quantity < sender_asset_quantity
                raise "you have #{target_asset.not_nil!.quantity} quantity of asset: #{sender_asset_id} so you cannot send #{sender_asset_quantity}"
              end
            else
              # sender has no quantity of the asset they are attempting to send
              raise "you have 0 quantity of asset: #{sender_asset_id} so you cannot send #{sender_asset_quantity}"
            end
          else
            raise "you have 0 quantity of asset: #{sender_asset_id} so you cannot send #{sender_asset_quantity}"
          end
        end

        vt << transaction
        processed_transactions << transaction
      rescue e : Exception
        vt << FailedTransaction.new(transaction, e.message || "unknown error")
      end
      vt
    end

    private def processed_quantities_per_asset(addresses : Array(String), processed_transactions : Array(Transaction)) : Hash(String, Array(AssetQuantity))
      addresses.uniq!
      amounts_per_address : Hash(String, Array(AssetQuantity)) = {} of String => Array(AssetQuantity)
      addresses.each { |a| amounts_per_address[a] = [] of AssetQuantity }

      recipient_sum_per_address = get_asset_recipient_sum_per_address(addresses, processed_transactions)
      sender_sum_per_address = get_asset_sender_sum_per_address(addresses, processed_transactions)
      create_update_sum_per_address = get_asset_create_update_sum_per_address(addresses, processed_transactions)

      # pp recipient_sum_per_address
      # pp sender_sum_per_address
      # pp create_update_sum_per_address

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

    private def get_asset_recipient_sum_per_address(addresses : Array(String), processed_transactions : Array(Transaction)) : Hash(String, Array(AssetQuantity))
      amounts_per_address : Hash(String, Array(AssetQuantity)) = {} of String => Array(AssetQuantity)
      addresses.each { |a| amounts_per_address[a] = [] of AssetQuantity }

      addresses.each do |address|
        address_recipients = processed_transactions.flat_map(&.recipients).select { |recipient| address == recipient.address }.select { |r| !r.asset_id.nil? }
        address_recipients.group_by(&.asset_id).each do |asset_id, recipients|
          amounts_per_address[address] << AssetQuantity.new(asset_id.not_nil!, recipients.compact_map(&.asset_quantity).sum)
        end
      end

      amounts_per_address
    end

    private def get_asset_sender_sum_per_address(addresses : Array(String), processed_transactions : Array(Transaction)) : Hash(String, Array(AssetQuantity))
      amounts_per_address : Hash(String, Array(AssetQuantity)) = {} of String => Array(AssetQuantity)
      addresses.each { |a| amounts_per_address[a] = [] of AssetQuantity }

      addresses.each do |address|
        address_senders = processed_transactions.flat_map(&.senders).select { |sender| address == sender.address }.select { |r| !r.asset_id.nil? }
        address_senders.group_by(&.asset_id).each do |asset_id, senders|
          amounts_per_address[address] << AssetQuantity.new(asset_id.not_nil!, senders.compact_map(&.asset_quantity).sum)
        end
      end

      amounts_per_address
    end

    private def get_asset_create_update_sum_per_address(addresses : Array(String), processed_transactions : Array(Transaction)) : Hash(String, Array(AssetQuantity))
      amounts_per_address : Hash(String, Array(AssetQuantity)) = {} of String => Array(AssetQuantity)
      addresses.each { |a| amounts_per_address[a] = [] of AssetQuantity }

      asset_transactions = processed_transactions.select { |t| ["create_asset", "update_asset"].includes?(t.action) }.reject(&.assets.empty?)
      asset_transactions.group_by(&.assets.first.asset_id).each do |ai, txns|
        # only use quantity from latest version of asset
        asset_versions = txns.flat_map(&.assets)
        latest_versions = asset_versions.select(&.version.==(asset_versions.map(&.version).max))

        sender_address = txns.first.senders.first.address
        amounts_per_address[sender_address] << AssetQuantity.new(ai, latest_versions.sum(&.quantity))
      end

      amounts_per_address
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
