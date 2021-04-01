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
  class AssetComponent < DApp
    def setup
    end

    def transaction_actions : Array(String)
      ASSET_ACTIONS
    end

    def transaction_related?(action : String) : Bool
      transaction_actions.includes?(action)
    end

    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      vt = ValidatedTransactions.empty
     
      processed_transactions = transactions.select(&.is_coinbase?)
      body_transactions = transactions.reject(&.is_coinbase?)

      existing_assets = database.existing_assets_from(body_transactions.flat_map(&.assets))

      body_transactions.each do |transaction|
        token = transaction.token
        action = transaction.action
      
        # common rules for transaction asset level
        #   raise "must not be the default token: #{token}" if token == TOKEN_DEFAULT
        raise "senders can only be 1 for asset action" if transaction.senders.size != 1
        raise "number of specified senders must be 1 for '#{action}'" if transaction.senders.size != 1
        raise "number of specified recipients must be 1 for '#{action}'" if transaction.recipients.size != 1
       
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


  
          # rules for create asset
          # asset_exists_in_db = existing_assets.find(&.==(asset))
          # asset_exists_in_transactions = processed_transactions.find{|t| t.action == "create_asset" && t.assets.includes?(asset)}

          # find if the token was locked within the current set of transactions
          # token_locked_in_transactions = processed_transactions.find { |processed_transaction|
          #   processed_transaction.token == token && processed_transaction.action == "lock_token"
          # }

          if action == "create_asset"
            raise "a transaction must have exactly 1 asset for '#{action}'" if transaction.assets.size != 1 

            asset = transaction.assets.first
            raise "asset_id must be length of 64 for '#{action}'" if asset.asset_id.size != 64
            raise "asset quantity must be 1 or more for '#{action}' with asset_id: #{asset.asset_id}" if asset.quantity <= 0

            asset_id_exists_in_db = existing_assets.find(&.asset_id.==(asset.asset_id))
            asset_id_exists_in_transactions = processed_transactions.find{|t| t.action == "create_asset" && t.assets.map(&.asset_id).includes?(asset.asset_id)}
            raise "asset_id must not already exist (asset_id: #{asset.asset_id}) '#{action}'" if asset_id_exists_in_db || asset_id_exists_in_transactions
            
            if !asset.media_location.empty?
            asset_media_location_exists_in_db = existing_assets.find(&.media_location.==(asset.media_location))
            asset_media_location_exists_in_transactions = processed_transactions.find{|t| t.action == "create_asset" && t.assets.map(&.media_location).includes?(asset.media_location)}
            raise "asset media_location must not already exist (asset_id: #{asset.asset_id}, media_location: #{asset.media_location}) '#{action}'" if asset_media_location_exists_in_db || asset_media_location_exists_in_transactions
            end

            if !asset.media_hash.empty?
            asset_media_hash_exists_in_db = existing_assets.find(&.media_hash.==(asset.media_hash))
            asset_media_hash_exists_in_transactions = processed_transactions.find{|t| t.action == "create_asset" && t.assets.map(&.media_hash).includes?(asset.media_hash)}
            raise "asset media_hash must not already exist (asset_id: #{asset.asset_id}, media_hash: #{asset.media_hash}) '#{action}'" if asset_media_hash_exists_in_db || asset_media_hash_exists_in_transactions
            end
          end

          # rules for just update
          # if action == "update_token"
          #   if (token_exists_in_db && token_map[token].is_locked) || !token_locked_in_transactions.nil?
          #     raise "the token: #{token} is locked and may no longer be updated"
          #   end
          # end

          # rules for just burn
          # if action == "burn_token"
          #   action_name = action.split("_").join(" ")
          #   # token must already exist either in the db or in current transactions
          #   raise "the token #{token} does not exist, you must create it before attempting to perform #{action_name}" unless (token_exists_in_db || token_exists_in_transactions)
          # end

          # rules for update and lock token
          # if ["update_token", "lock_token"].includes?(action)
          #   action_name = action.split("_").join(" ")

          #   # token must already exist either in the db or in current transactions
          #   raise "the token #{token} does not exist, you must create it before attempting to perform #{action_name}" unless (token_exists_in_db || token_exists_in_transactions)

          #   unless token_exists_in_transactions.nil?
          #     token_creator = token_exists_in_transactions.not_nil!.recipients[0].address
          #     raise "only the token creator can perform #{action_name} on existing token: #{token}" unless token_creator == recipient_address
          #   end

          #   if token_exists_in_db
          #     raise "only the token creator can perform #{action_name} on existing token: #{token}" unless token_map[token].created_by == recipient_address
          #   end
          # end

          # rules for just lock token
          # if action == "lock_token"
          #   raise "the sender amount must be 0 when locking the token: #{token}" unless recipient_amount == 0_i64

          #   if (token_exists_in_db && token_map[token].is_locked) || !token_locked_in_transactions.nil?
          #     raise "the token: #{token} is already locked"
          #   end
          # end
       

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
