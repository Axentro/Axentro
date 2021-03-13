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

require "./transaction/models"
require "json_mapping"

module ::Axentro::Core
  class Transaction
    JSON.mapping(
      id: String,
      action: String,
      senders: Array(Sender),
      recipients: Recipients,
      message: String,
      token: String,
      prev_hash: String,
      timestamp: Int64,
      scaled: Int32,
      kind: TransactionKind,
      version: TransactionVersion
    )

    setter prev_hash : String
    @common_validated : Bool = false

    # def to_json(j : JSON::Builder)
    #   j.object do
    #     j.field("id", @id)
    #     j.field("action", @action)
    #     j.field("message", @message)
    #     j.field("token", @token)
    #     j.field("prev_hash", @prev_hash)
    #     j.field("timestamp", @timestamp)
    #     j.field("scaled", @scaled)
    #     j.field("kind", @kind.to_s)
    #     j.field("version", @version.to_s)
    #     j.field("senders", @senders.to_json)
    #     j.field("recipients", @recipients.to_json)
    #   end
    # end

    def initialize(
      @id : String,
      @action : String,
      @senders : Array(Sender),
      @recipients : Recipients,
      @message : String,
      @token : String,
      @prev_hash : String,
      @timestamp : Int64,
      @scaled : Int32,
      @kind : TransactionKind,
      @version : TransactionVersion
    )
    end

    def set_common_validated : Core::Transaction
      @common_validated = true
      self
    end

    def is_common_validated?
      @common_validated
    end

    def is_coinbase?
      @action == "head"
    end

    def add_prev_hash(prev_hash : String) : Transaction
      unless is_coinbase?
        self.prev_hash = prev_hash
      end
      self
    end

    def self.create_id : String
      tmp_id = Random::Secure.hex(32)
      return create_id if tmp_id[0] == "0"
      tmp_id
    end

    def to_hash : String
      string = self.to_json
      sha256(string)
    end

    def short_id : String
      @id[0..7]
    end

    def self.short_id(txn_id) : String
      txn_id[0..7]
    end

    def as_unsigned : Transaction
      unsigned_senders = self.senders.map do |s|
        Sender.new(s.address, s.public_key, s.amount, s.fee, "0")
      end

      Transaction.new(
        self.id,
        self.action,
        unsigned_senders,
        self.recipients,
        self.message,
        self.token,
        "0",
        self.timestamp,
        self.scaled,
        self.kind,
        self.version
      )
    end

    def as_signed(wallets : Array(Wallet)) : Transaction
      signed_senders = self.senders.map_with_index { |s, i|
        private_key = Wif.new(wallets[i].wif).private_key
        signature = KeyUtils.sign(private_key.as_hex, self.to_hash)
        Sender.new(s.address, s.public_key, s.amount, s.fee, signature)
      }

      Transaction.new(
        self.id,
        self.action,
        signed_senders,
        self.recipients,
        self.message,
        self.token,
        "0",
        self.timestamp,
        self.scaled,
        self.kind,
        self.version
      )
    end

    def is_slow_transaction?
      self.kind == TransactionKind::SLOW
    end

    def is_fast_transaction?
      self.kind == TransactionKind::FAST
    end

    def sender_total_amount : Int64
      senders.reduce(0_i64) { |sum, sender| sum + sender.amount }
    end

    def recipient_total_amount : Int64
      recipients.reduce(0_i64) { |sum, recipient| sum + recipient.amount }
    end

    def total_fees : Int64
      senders.reduce(0_i64) { |sum, sender| sum + sender.fee }
    end

    def set_senders(@senders)
    end

    def set_recipients(@recipients)
    end

    #
    # ignore prev_hash for comparison
    #
    def ==(other : Transaction) : Bool
      return false unless @id == other.id
      return false unless @action == other.action
      return false unless @senders == other.senders
      return false unless @recipients == other.recipients
      return false unless @token == other.token
      return false unless @timestamp == other.timestamp
      return false unless @scaled == other.scaled
      return false unless @kind == other.kind
      return false unless @version == other.version

      true
    end

    include Hashes
    include Logger
    include TransactionModels
    include Common::Validator
    include Common::Denomination
  end
end

require "./transaction/*"
