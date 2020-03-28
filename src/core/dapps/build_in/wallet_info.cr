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

  struct IncomingWalletTransaction
    JSON.mapping(
      transaction_id: String,
      kind: String,
      from: String,
      from_readable: String,
      category: String,
      datetime: String,
      status: String,
    )

    def initialize(@transaction_id : String, @kind : String, @from : String, @from_readable : String, @category : String, @datetime : String, @status : String); end
  end

  struct OutgoingWalletTransaction
    JSON.mapping(
      transaction_id: String,
      kind: String,
      to: String,
      to_readable: String,
      category: String,
      datetime: String,
      status: String,
    )

    def initialize(@transaction_id : String, @kind : String, @to : String, @to_readable : String, @category : String, @datetime : String, @status : String); end
  end

  struct RejectedWalletTransaction
    JSON.mapping(
      transaction_id: String,
      rejection_reason: String,
      status: String
    )

    def initialize(@transaction_id : String, @rejection_reason : String, @status : String = "Rejected"); end
  end

  struct IncomingTransactions
    JSON.mapping(
      pending_transactions: Array(IncomingWalletTransaction),
      completed_transactions: Array(IncomingWalletTransaction),
    )

    def initialize(@pending_transactions : Array(IncomingWalletTransaction), @completed_transactions : Array(IncomingWalletTransaction)); end
  end

  struct OutgoingTransactions
    JSON.mapping(
      pending_transactions: Array(OutgoingWalletTransaction),
      completed_transactions: Array(OutgoingWalletTransaction),
    )

    def initialize(@pending_transactions : Array(OutgoingWalletTransaction), @completed_transactions : Array(OutgoingWalletTransaction)); end
  end

  struct WalletInfoResponse
    JSON.mapping(
      address: String,
      readable: Array(String),
      tokens: Array(TokenAmount),
      incoming_transactions: IncomingTransactions,
      outgoing_transactions: OutgoingTransactions,
      rejected_transactions: Array(RejectedWalletTransaction),
    )

    def initialize(@address : String, @readable : Array(String), @tokens : Array(TokenAmount),
                   @incoming_transactions : IncomingTransactions,
                   @outgoing_transactions : OutgoingTransactions,
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
      incoming_completed_transactions = incoming("Completed", all_completed_transactions.select { |t| t.recipients.map { |r| r[:address] }.includes?(address) })
      outgoing_completed_transactions = outgoing("Completed", all_completed_transactions.select { |t| t.senders.map { |r| r[:address] }.includes?(address) })

      incoming_pending_transactions = incoming("Pending", (blockchain.pending_slow_transactions + blockchain.pending_fast_transactions).select { |t| t.recipients.map { |r| r.[:address] }.includes?(address) })
      outgoing_pending_transactions = outgoing("Pending", (blockchain.pending_slow_transactions + blockchain.pending_fast_transactions).select { |t| t.senders.map { |r| r.[:address] }.includes?(address) })

      WalletInfoResponse.new(address, readable, tokens,
        IncomingTransactions.new(incoming_pending_transactions, incoming_completed_transactions),
        OutgoingTransactions.new(outgoing_pending_transactions, outgoing_completed_transactions),
        [] of RejectedWalletTransaction
      )
    end

    private def outgoing(status : String, transactions : Array(Transaction)) : Array(OutgoingWalletTransaction)
      transactions.map do |t|
        OutgoingWalletTransaction.new(
          t.id, t.kind.to_s, t.senders.map(&.[:address]).first,
          domain_for_senders(t.senders), "Incoming", t.timestamp.to_s, status
        )
      end
    end

    private def incoming(status : String, transactions : Array(Transaction)) : Array(IncomingWalletTransaction)
      transactions.map do |t|
        IncomingWalletTransaction.new(
          t.id, t.kind.to_s, t.recipients.map(&.[:address]).first,
          domain_for_recipients(t.recipients), "Outgoing", t.timestamp.to_s, status
        )
      end
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
