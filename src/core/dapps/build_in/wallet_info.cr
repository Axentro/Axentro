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

module ::Sushi::Core::DApps::BuildIn
  struct TokenAmount
    JSON.mapping(
      name: String,
      amount: String
    )

    def initialize(@name : String, @amount : String); end
  end

  struct RecentWalletTransaction
    JSON.mapping(
      transaction_id: String,
      kind: String,
      from: String,
      from_readable: String,
      to: String,
      to_readable: String,
      amount: String,
      token: String,
      category: String,
      datetime: String,
      status: String,
      direction: String
    )

    def initialize(@transaction_id : String, @kind : String, @from : String, @from_readable : String, @to : String, @to_readable : String, @amount : String, @token : String, @category : String, @datetime : String, @status : String, @direction : String); end
  end

  struct RejectedWalletTransaction
    JSON.mapping(
      transaction_id: String,
      rejection_reason: String,
      status: String
    )

    def initialize(@transaction_id : String, @rejection_reason : String, @status : String = "Rejected"); end
  end

  struct WalletInfoResponse
    JSON.mapping(
      address: String,
      readable: Array(String),
      tokens: Array(TokenAmount),
      recent_transactions: Array(RecentWalletTransaction),
      rejected_transactions: Array(RejectedWalletTransaction),
    )

    def initialize(@address : String, @readable : Array(String), @tokens : Array(TokenAmount),
                   @recent_transactions : Array(RecentWalletTransaction),
                   @rejected_transactions : Array(RejectedWalletTransaction)); end
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

    def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      true
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
      tokens = database.get_address_amount(address).map { |tq| TokenAmount.new(tq.token, scale_decimal(tq.amount)) }

      page, per_page, direction = 0, 100, 1

      all_completed_transactions = database.get_paginated_transactions_for_address(address, page, per_page, Direction.new(direction).to_s, [] of String)
      incoming_completed_transactions = incoming(address, "Completed", all_completed_transactions.select { |t| t.recipients.map { |r| r[:address] }.includes?(address) })
      outgoing_completed_transactions = outgoing(address, "Completed", all_completed_transactions.select { |t| t.senders.map { |r| r[:address] }.includes?(address) })

      incoming_pending_transactions = incoming(address, "Pending", (blockchain.pending_slow_transactions + blockchain.pending_fast_transactions).select { |t| t.recipients.map { |r| r.[:address] }.includes?(address) })
      outgoing_pending_transactions = outgoing(address, "Pending", (blockchain.pending_slow_transactions + blockchain.pending_fast_transactions).select { |t| t.senders.map { |r| r.[:address] }.includes?(address) })

      recent_transactions = incoming_completed_transactions + outgoing_completed_transactions + incoming_pending_transactions + outgoing_pending_transactions

      WalletInfoResponse.new(address, readable, tokens, recent_transactions.sort_by(&.datetime).reverse, [] of RejectedWalletTransaction)
    end

    private def outgoing(address, status : String, transactions : Array(Transaction)) : Array(RecentWalletTransaction)
      transactions.map do |t|
        RecentWalletTransaction.new(
          t.id, t.kind.to_s, "", "", first_recipient(t.recipients),
          domain_for_recipients(t.recipients), amount_for_senders(address, t.senders), t.token, category(t.action),
          Time.unix_ms(t.timestamp).to_s, status, "Outgoing"
        )
      end
    end

    private def incoming(address, status : String, transactions : Array(Transaction)) : Array(RecentWalletTransaction)
      transactions.map do |t|
        RecentWalletTransaction.new(
          t.id, t.kind.to_s, first_sender(t.senders), domain_for_senders(t.senders), "", "",
           amount_for_recipients(address, t.recipients), t.token, category(t.action),
           Time.unix_ms(t.timestamp).to_s, status, "Incoming"
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

    private def category(action : String) : String
      case action
      when "head"
        "Mining reward"
      when "send"
        "Payment"
      when "scars_buy"
        "Payment (Human readable address)"
      when "scars_sell"
        "Payment (Human readable address)"    
      else
        action
      end    
    end

    private def amount_for_recipients(address, recipients) : String
      scale_decimal(recipients.select{|r| r[:address] == address}.map(&.[:amount]).reduce(0_i64){|acc,v| acc + v})
    end

    private def amount_for_senders(address, senders) : String
      scale_decimal(senders.select{|s| s[:address] == address}.map(&.[:amount]).reduce(0_i64){|acc,v| acc + v})
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
