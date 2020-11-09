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
  struct RecentWalletTransaction
    include JSON::Serializable
    property transaction_id : String
    property kind : String
    property from : String
    property from_readable : String
    property to : String
    property to_readable : String
    property amount : String
    property token : String
    property category : String
    property datetime : String
    property fee : String
    property status : String
    property direction : String
    property data : String
    property confirmations : String

    def initialize(@transaction_id : String, @kind : String, @from : String, @from_readable : String, @to : String, @to_readable : String, @amount : String, @token : String, @category : String, @datetime : String, @fee : String, @data : String, @status : String, @direction : String, @confirmations : String); end
  end

  struct RejectedWalletTransaction
    include JSON::Serializable
    property transaction_id : String
    property sender_address : String
    property rejection_reason : String
    property datetime : String
    property status : String

    def initialize(@transaction_id : String, @sender_address : String, @rejection_reason : String, @datetime : String, @status : String = "Rejected"); end
  end

  struct WalletInfoResponse
    include JSON::Serializable
    property address : String
    property readable : Array(String)
    property tokens : Array(TokenData)
    property my_tokens : Array(TokenData)
    property recent_transactions : Array(RecentWalletTransaction)
    property rejected_transactions : Array(RejectedWalletTransaction)

    def initialize(@address : String, @readable : Array(String), @tokens : Array(TokenData), @my_tokens : Array(TokenData),
                   @recent_transactions : Array(RecentWalletTransaction),
                   @rejected_transactions : Array(RejectedWalletTransaction)); end
  end

  struct TokenData
    include JSON::Serializable
    property token : String
    property is_locked : Bool
    property is_mine : Bool
    property amount : String

    def initialize(@token : String, @is_locked : Bool, @is_mine : Bool, @amount : String)
    end
  end

  class WalletInfo < DApp
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
      when "wallet_info"
        return wallet_info(json, context, params)
      end

      nil
    end

    def wallet_info(json, context, params)
      address = json["address"].as_s
      context.response.print api_success(wallet_info_impl(address))
      context
    end

    def wallet_info_impl(address)
      readable = database.get_domain_map_for_address(address).keys

      _tokens = database.get_address_amount(address)
      token_info = database.token_info(_tokens.map(&.token))

      tokens = _tokens.map do |tq|
        if token_info[tq.token]?
          ti = token_info[tq.token]
          TokenData.new(tq.token, ti.is_locked, ti.created_by == address, scale_decimal(tq.amount))
        else
          TokenData.new(tq.token, false, false, scale_decimal(tq.amount))
        end
      end

      my_tokens = tokens.select(&.is_mine)

      page, per_page, direction = 0, 100, 1

      all_completed_transactions = database.get_paginated_transactions_for_address(address, page, per_page, Direction.new(direction).to_s, [] of String, true)
      incoming_completed_transactions = incoming(address, "Completed", all_completed_transactions.select { |t| t.recipients.map { |r| r[:address] }.includes?(address) })
      outgoing_completed_transactions = outgoing(address, "Completed", all_completed_transactions.select { |t| t.senders.map { |r| r[:address] }.includes?(address) })

      incoming_pending_transactions = incoming(address, "Pending", (blockchain.pending_slow_transactions + blockchain.pending_fast_transactions).select { |t| t.recipients.map { |r| r.[:address] }.includes?(address) })
      outgoing_pending_transactions = outgoing(address, "Pending", (blockchain.pending_slow_transactions + blockchain.pending_fast_transactions).select { |t| t.senders.map { |r| r.[:address] }.includes?(address) })

      recent_transactions = incoming_completed_transactions + outgoing_completed_transactions + incoming_pending_transactions + outgoing_pending_transactions
      rejected_transactions = rejections(database.find_reject_by_address(address))

      recent_non_rejected_transactions = recent_transactions.reject { |t| rejected_transactions.map(&.transaction_id).includes?(t.transaction_id) }

      # TODO = if sending to self - merge the incoming and outgoing together

      WalletInfoResponse.new(address, readable, tokens, my_tokens, recent_non_rejected_transactions.sort_by(&.datetime).reverse, rejected_transactions)
    end

    private def rejections(rejects : Array(Reject)) : Array(RejectedWalletTransaction)
      rejects.map do |t|
        RejectedWalletTransaction.new(
          t.transaction_id, t.sender_address, t.reason, Time.unix_ms(t.timestamp).to_s)
      end
    end

    private def outgoing(address, status : String, transactions : Array(Transaction)) : Array(RecentWalletTransaction)
      transactions.map do |t|
        confirmations = 0
        if block_index = database.get_block_index_for_transaction(t.id)
          confirmations = database.get_confirmations(block_index)
        end

        RecentWalletTransaction.new(
          t.id, t.kind.to_s, "", "", first_recipient(t.recipients),
          domain_for_recipients(t.recipients), amount_for_senders(address, t.senders), t.token, category(t.action, t.kind),
          Time.unix_ms(t.timestamp).to_s, fee_for_senders(address, t.senders), t.message, status, "Outgoing", confirmations.to_s
        )
      end
    end

    private def incoming(address, status : String, transactions : Array(Transaction)) : Array(RecentWalletTransaction)
      transactions.map do |t|
        confirmations = 0
        if block_index = database.get_block_index_for_transaction(t.id)
          confirmations = database.get_confirmations(block_index)
        end

        RecentWalletTransaction.new(
          t.id, t.kind.to_s, first_sender(t.senders), domain_for_senders(t.senders), "", "",
          amount_for_recipients(address, t.recipients), t.token, category(t.action, t.kind),
          Time.unix_ms(t.timestamp).to_s, fee_for_senders(address, t.senders), t.message, status, "Incoming", confirmations.to_s
        )
      end
    end

    private def first_recipient(recipients)
      r = recipients.map(&.[:address])
      r.size > 0 ? r.first : ""
    end

    private def first_sender(senders)
      s = senders.map(&.[:address])
      s.size > 0 ? s.first : ""
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def category(action : String, kind : TransactionKind) : String
      case action
      when "head"
        if kind == TransactionKind::FAST
          "Maintenance fund"
        else
          "Mining reward"
        end
      when "send"
        "Payment"
      when "hra_buy"
        "Payment (Human readable address)"
      when "hra_sell"
        "Payment (Human readable address)"
      when "hra_cancel"
        "Cancel (Human readable address)"
      when "create_token"
        "Create token"
      when "update_token"
        "Update token"
      when "lock_token"
        "Lock token"
      when "create_official_node_slow"
        "Create slow official node"
      when "create_official_node_fast"
        "Create fast official node"
      else
        action
      end
    end

    private def amount_for_recipients(address, recipients) : String
      scale_decimal(recipients.select { |r| r[:address] == address }.map(&.[:amount]).reduce(0_i64) { |acc, v| acc + v })
    end

    private def amount_for_senders(address, senders) : String
      scale_decimal(senders.select { |s| s[:address] == address }.map(&.[:amount]).reduce(0_i64) { |acc, v| acc + v })
    end

    private def fee_for_senders(address, senders) : String
      scale_decimal(senders.select { |s| s[:address] == address }.map(&.[:fee]).reduce(0_i64) { |acc, v| acc + v })
    end

    private def domain_for_senders(senders) : String
      _senders = senders.map(&.[:address]).uniq
      if _senders.size > 0
        domains = _senders.flat_map { |address| database.get_domain_map_for_address(address).keys.uniq }
        if domains.size > 0
          domains.first
        else
          ""
        end
      else
        ""
      end
    end

    private def domain_for_recipients(recipients) : String
      _recipients = recipients.map(&.[:address]).uniq
      if _recipients.size > 0
        domains = _recipients.flat_map { |address| database.get_domain_map_for_address(address).keys.uniq }
        if domains.size > 0
          domains.first
        else
          ""
        end
      else
        ""
      end
    end

    def on_message(action : String, from_address : String, content : String, from = nil)
      false
    end
  end
end
