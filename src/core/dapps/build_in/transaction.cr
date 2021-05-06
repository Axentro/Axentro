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
  class TransactionCreator < DApp
    def setup
    end

    def transaction_actions : Array(String)
      [] of String
    end

    def transaction_related?(action : String) : Bool
      false
    end

    def valid_transactions?(transactions : Array(Transaction)) : ValidatedTransactions
      ValidatedTransactions.passed(transactions)
    end

    def record(chain : Blockchain::Chain)
    end

    def clear
    end

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
      case call
      when "create_unsigned_transaction"
        return create_unsigned_transaction(json, context, params)
      when "create_transaction"
        return create_transaction(json, context, params)
      end

      nil
    end

    def create_unsigned_transaction(json, context, params)
      action = json["action"].as_s
      senders = SendersDecimal.from_json(json["senders"].to_json)
      recipients = RecipientsDecimal.from_json(json["recipients"].to_json)
      assets = Assets.from_json(json["assets"].to_json)
      modules = Modules.from_json(json["modules"].to_json)
      inputs = Inputs.from_json(json["inputs"].to_json)
      outputs = Outputs.from_json(json["outputs"].to_json)
      linked = json["linked"].as_s
      message = json["message"].as_s
      token = json["token"].as_s
      kind = TransactionKind.parse(json["kind"].as_s)
      version = TransactionVersion.parse(json["version"].as_s)

      transaction = create_unsigned_transaction_impl(action, senders, recipients, assets, modules, inputs, outputs, linked, message, token, kind, version)

      context.response.print api_success(transaction)
      context
    end

    def create_sender(amount : String, address : String, public_key : String, fee : String, asset_id : String? = nil, asset_quantity : Int32? = nil) : SendersDecimal
      senders = SendersDecimal.new
      senders.push(
        SenderDecimal.new(address, public_key, amount, fee, "0", asset_id, asset_quantity))
      senders
    end

    def create_recipient(address : String, amount : String, asset_id : String? = nil, asset_quantity : Int32? = nil) : RecipientsDecimal
      recipients = RecipientsDecimal.new
      recipients.push(
        RecipientDecimal.new(address, amount, asset_id, asset_quantity))
      recipients
    end

    def create_unsigned_send_token_impl(
      to_address : String,
      from_address : String,
      amount : String,
      fee : String,
      kind : TransactionKind,
      public_key : String
    )
      senders = create_sender(amount, from_address, public_key, fee)
      recipients = create_recipient(to_address, amount)

      create_unsigned_transaction_impl(
        "send",
        senders,
        recipients,
        [] of Transaction::Asset,
        [] of Transaction::Module,
        [] of Transaction::Input,
        [] of Transaction::Output,
        "", # linked
        "",
        "AXNT",
        kind,
        TransactionVersion::V1,
        Transaction.create_id
      )
    end

    def create_unsigned_send_asset_impl(
      to_address : String,
      from_address : String,
      asset_id : String,
      amount : Int32,
      kind : TransactionKind,
      public_key : String
    )
      senders = create_sender("0", from_address, public_key, "0", asset_id, amount)
      recipients = create_recipient(to_address, "0", asset_id, amount)

      create_unsigned_transaction_impl(
        "send_asset",
        senders,
        recipients,
        [] of Transaction::Asset,
        [] of Transaction::Module,
        [] of Transaction::Input,
        [] of Transaction::Output,
        "", # linked
        "",
        "AXNT",
        kind,
        TransactionVersion::V1,
        Transaction.create_id
      )
    end

    def create_unsigned_create_asset_impl(
      address : String,
      public_key : String,
      name : String,
      description : String,
      media_location : String,
      media_hash : String,
      quantity : Int32,
      terms : String,
      locked : AssetAccess,
      version : Int32,
      timestamp : Int64,
      kind : TransactionKind
    )
      senders = create_sender("0", address, public_key, "0")
      recipients = create_recipient(address, "0")
      asset = Transaction::Asset.new(Transaction::Asset.create_id, name, description, media_location, media_hash, quantity, terms, locked, version, timestamp)

      create_unsigned_transaction_impl(
        "create_asset",
        senders,
        recipients,
        [asset],
        [] of Transaction::Module,
        [] of Transaction::Input,
        [] of Transaction::Output,
        "", # linked
        "",
        "AXNT",
        kind,
        TransactionVersion::V1,
        Transaction.create_id
      )
    end

    def create_unsigned_update_asset_impl(
      address : String,
      public_key : String,
      asset : Transaction::Asset,
      kind : TransactionKind
    )
      senders = create_sender("0", address, public_key, "0")
      recipients = create_recipient(address, "0")

      create_unsigned_transaction_impl(
        "create_asset",
        senders,
        recipients,
        [asset],
        [] of Transaction::Module,
        [] of Transaction::Input,
        [] of Transaction::Output,
        "", # linked
        "",
        "AXNT",
        kind,
        TransactionVersion::V1,
        Transaction.create_id
      )
    end

    def create_unsigned_transaction_impl(
      action : String,
      senders : SendersDecimal,
      recipients : RecipientsDecimal,
      assets : Assets,
      modules : Modules,
      inputs : Inputs,
      outputs : Outputs,
      linked : String,
      message : String,
      token : String,
      kind : TransactionKind,
      version : TransactionVersion,
      id : String = Transaction.create_id
    )
      transaction = TransactionDecimal.new(
        id,
        action,
        senders,
        recipients,
        assets,
        modules,
        inputs,
        outputs,
        linked,
        message,
        token,
        "0",         # prev_hash
        __timestamp, # timestamp
        0,           # scaled
        kind,
        version
      ).to_transaction

      if !ASSET_ACTIONS.includes?(action)
        fee = transaction.total_fees

        minimum_fee = if _fee = blockchain.fees.fees_impl[action]?
                        scale_i64(_fee)
                      else
                        Core::DApps::BuildIn::UTXO.fee("send")
                      end

        raise "the fee (#{scale_decimal(fee)}) is less than the minimum fee (#{scale_decimal(minimum_fee)})." if fee < minimum_fee
      end

      transaction
    end

    def create_transaction(json, context, params)
      transaction = Transaction.from_json(json["transaction"].to_json)
      transaction = create_transaction_impl(transaction)

      context.response.print api_success(transaction)
      context
    end

    def create_transaction_impl(transaction : Transaction)
      node.broadcast_transaction(transaction)

      transaction
    end

    def on_message(action : String, from_address : String, content : String, from = nil) : Bool
      false
    end

    include TransactionModels
    include Common::Timestamp
  end
end
