# Copyright © 2017-2018 The Axentro Core developers
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
    MESSAGE_SIZE_LIMIT = 512
    TOKEN_SIZE_LIMIT   =  16

    JSON.mapping(
      id: String,
      action: String,
      senders: Senders,
      recipients: Recipients,
      message: String,
      token: String,
      prev_hash: String,
      timestamp: Int64,
      scaled: Int32,
      kind: TransactionKind
    )
    # include JSON::Serializable
    # property id : String
    # property action : String
    # property senders : Senders
    # property recipients : Recipients
    # property message : String
    # property token : String
    # property prev_hash : String
    # property timestamp : Int64
    # property scaled : Int32
    # property kind : TransactionKind

    setter prev_hash : String
    @common_checked : Bool = false

    def initialize(
      @id : String,
      @action : String,
      @senders : Senders,
      @recipients : Recipients,
      @message : String,
      @token : String,
      @prev_hash : String,
      @timestamp : Int64,
      @scaled : Int32,
      @kind : TransactionKind
    )
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

    def valid_as_embedded?(blockchain : Blockchain, prev_transactions : Array(Transaction)) : Bool
      verbose "tx -- #{short_id}: validating embedded transactions"

      raise "transactions have not been validated" unless @common_checked

      if sender_total_amount != recipient_total_amount
        raise "amount mismatch for senders (#{scale_decimal(sender_total_amount)}) " +
              "and recipients (#{scale_decimal(recipient_total_amount)})"
      end

      if @prev_hash != prev_transactions[-1].to_hash
        raise "invalid prev_hash: expected #{prev_transactions[-1].to_hash} but got #{@prev_hash}"
      end

      blockchain.dapps.each do |dapp|
        if dapp.transaction_related?(@action) && prev_transactions.size > 0
          dapp.valid?(self, prev_transactions)
        end
      end

      true
    end

    def valid_as_coinbase?(blockchain : Blockchain, block_index : Int64, embedded_transactions : Array(Transaction)) : Bool
      verbose "tx -- #{short_id}: validating coinbase transaction"

      raise "transactions have not been validated" unless @common_checked

      raise "actions has to be 'head' for coinbase transaction " if @action != "head"
      raise "message has to be '0' for coinbase transaction" if @message != "0"
      raise "token has to be #{TOKEN_DEFAULT} for coinbase transaction" if @token != TOKEN_DEFAULT
      raise "there should be no Sender for a coinbase transaction" if @senders.size != 0
      raise "prev_hash of coinbase transaction has to be '0'" if @prev_hash != "0"

      served_sum = @recipients.reduce(0_i64) { |sum, recipient| sum + recipient[:amount] }

      served_sum_expected = self.is_slow_transaction? ? blockchain.coinbase_slow_amount(block_index, embedded_transactions) : blockchain.coinbase_fast_amount(block_index, embedded_transactions)

      if served_sum != served_sum_expected
        raise "invalid served amount for coinbase transaction at index: #{block_index} " +
              "expected #{served_sum_expected} but got #{served_sum} "
      end

      true
    end

    def valid_common? : Bool
      return true if @common_checked

      verbose "tx -- #{short_id}: validating common"

      raise "length of transaction id has to be 64: #{@id}" if @id.size != 64
      raise "message size exceeds: #{self.message.bytesize} for #{MESSAGE_SIZE_LIMIT}" if self.message.bytesize > MESSAGE_SIZE_LIMIT
      raise "token size exceeds: #{self.token.bytesize} for #{TOKEN_SIZE_LIMIT}" if self.token.bytesize > TOKEN_SIZE_LIMIT
      raise "unscaled transaction" if @scaled != 1

      @senders.each do |sender|
        network = Keys::Address.from(sender[:address], "sender").network
        public_key = Keys::PublicKey.new(sender[:public_key], network)

        if public_key.address.as_hex != sender[:address]
          raise "sender public key mismatch - sender public key: #{public_key.as_hex} is not for sender address: #{sender[:address]}"
        end

        verbose "unsigned_json: #{self.as_unsigned.to_json}"
        verbose "unsigned_json_hash: #{self.as_unsigned.to_hash}"
        verbose "public key: #{public_key.as_hex}"
        verbose "signature: #{sender[:signature]}"

        verify_result = KeyUtils.verify_signature(self.as_unsigned.to_hash, sender[:signature], public_key.as_hex)

        verbose "verify signature result: #{verify_result}"

        if !verify_result
          raise "invalid signing for sender: #{sender[:address]}"
        end

        unless Keys::Address.from(sender[:address], "sender")
          raise "invalid checksum for sender's address: #{sender[:address]}"
        end

        valid_amount?(sender[:amount])
      end

      @recipients.each do |recipient|
        unless Keys::Address.from(recipient[:address], "recipient")
          raise "invalid checksum for recipient's address: #{recipient[:address]}"
        end

        valid_amount?(recipient[:amount])
      end

      @common_checked = true

      true
    end

    def as_unsigned : Transaction
      unsigned_senders = self.senders.map { |s|
        {
          address:    s[:address],
          public_key: s[:public_key],
          amount:     s[:amount],
          fee:        s[:fee],
          signature:  "0",
        }
      }

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
        self.kind
      )
    end

    def as_signed(wallets : Array(Wallet)) : Transaction
      signed_senders = self.senders.map_with_index { |s, i|
        private_key = Wif.new(wallets[i].wif).private_key

        signature = KeyUtils.sign(private_key.as_hex, self.to_hash)

        {
          address:    s[:address],
          public_key: s[:public_key],
          amount:     s[:amount],
          fee:        s[:fee],
          signature:  signature,
        }
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
        self.kind
      )
    end

    def is_slow_transaction?
      self.kind == TransactionKind::SLOW
    end

    def is_fast_transaction?
      self.kind == TransactionKind::FAST
    end

    def sender_total_amount : Int64
      senders.reduce(0_i64) { |sum, sender| sum + sender[:amount] }
    end

    def recipient_total_amount : Int64
      recipients.reduce(0_i64) { |sum, recipient| sum + recipient[:amount] }
    end

    def total_fees : Int64
      senders.reduce(0_i64) { |sum, sender| sum + sender[:fee] }
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
