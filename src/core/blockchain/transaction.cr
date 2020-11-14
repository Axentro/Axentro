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
  module Validation::Transaction
    extend self

    MESSAGE_SIZE_LIMIT = 512
    TOKEN_SIZE_LIMIT   =  16

    def validate_embedded(transactions : Array(Core::Transaction), blockchain : Blockchain, skip_prev_hash_check : Bool = false) : ValidatedTransactions
      vt = ValidatedTransactions.empty

      # (coinbase are validated in validate_coinbase) and are required to pass into dapps (mainly for utxo)
      transactions.select(&.is_coinbase?).map(&.as_validated).each { |validated| vt << validated }

      # only applies to non coinbase transactions and returns all non coinbase transactions
      vt << Validation::Transaction::Rules::Sender.rule_sender_mismatches(transactions)

      unless skip_prev_hash_check
        vt << Validation::Transaction::Rules::PrevHash.rule_prev_hashes(vt.passed)
      end

      blockchain.dapps.each do |dapp|
        related_transactions = vt.passed.select { |t| dapp.transaction_related?(t.action) }
        if related_transactions.size > 0
          vt << dapp.valid?(related_transactions)
        end
      end

      vt
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def validate_common(transactions : Array(Core::Transaction), network_type : String) : ValidatedTransactions
      vt = ValidatedTransactions.empty
      transactions.each do |transaction|
        raise "length of transaction id has to be 64: #{transaction.id}" if transaction.id.size != 64
        raise "message size exceeds: #{transaction.message.bytesize} for #{MESSAGE_SIZE_LIMIT}" if transaction.message.bytesize > MESSAGE_SIZE_LIMIT
        raise "token size exceeds: #{transaction.token.bytesize} for #{TOKEN_SIZE_LIMIT}" if transaction.token.bytesize > TOKEN_SIZE_LIMIT
        raise "unscaled transaction" if transaction.scaled != 1

        transaction.senders.each do |sender|
          network = Keys::Address.from(sender[:address], "sender").network
          raise "sender address: #{sender[:address]} has wrong network type: #{network[:name]}, this node is running as: #{network_type}" if network[:name] != network_type

          public_key = Keys::PublicKey.new(sender[:public_key], network)

          if public_key.address.as_hex != sender[:address]
            raise "sender public key mismatch - sender public key: #{public_key.as_hex} is not for sender address: #{sender[:address]}"
          end

          verbose "unsigned_json: #{transaction.as_unsigned.to_json}"
          verbose "unsigned_json_hash: #{transaction.as_unsigned.to_hash}"
          verbose "public key: #{public_key.as_hex}"
          verbose "signature: #{sender[:signature]}"

          verify_result = KeyUtils.verify_signature(transaction.as_unsigned.to_hash, sender[:signature], public_key.as_hex)

          verbose "verify signature result: #{verify_result}"

          if !verify_result
            raise "invalid signing for sender: #{sender[:address]}"
          end

          unless Keys::Address.from(sender[:address], "sender")
            raise "invalid checksum for sender's address: #{sender[:address]}"
          end

          valid_amount?(sender[:amount])
        end

        transaction.recipients.each do |recipient|
          recipient_address = Keys::Address.from(recipient[:address], "recipient")
          unless recipient_address
            raise "invalid checksum for recipient's address: #{recipient[:address]}"
          end

          network = recipient_address.network
          raise "recipient address: #{recipient[:address]} has wrong network type: #{network[:name]}, this node is running as: #{network_type}" if network[:name] != network_type

          valid_amount?(recipient[:amount])
        end

        transaction = transaction.set_common_validated
        vt << transaction.as_validated
      rescue e : Exception
        vt << FailedTransaction.new(transaction, e.message || "unknown error", "validate_common").as_validated
      end
      vt
    end

    def validate_coinbase(coinbase_transactions : Array(Core::Transaction), embedded_transactions : Array(Core::Transaction), blockchain : Blockchain, block_index : Int64) : ValidatedTransactions
      vt = ValidatedTransactions.empty
      coinbase_transactions.each do |transaction|
        raise "actions has to be 'head' for coinbase transaction" if transaction.action != "head"
        raise "message has to be '0' for coinbase transaction" if transaction.message != "0"
        raise "token has to be #{TOKEN_DEFAULT} for coinbase transaction" if transaction.token != TOKEN_DEFAULT
        raise "there should be no Sender for a coinbase transaction" if transaction.senders.size != 0
        raise "prev_hash of coinbase transaction has to be '0'" if transaction.prev_hash != "0"

        served_sum = transaction.recipients.reduce(0_i64) { |sum, recipient| sum + recipient[:amount] }
        served_sum_expected = transaction.is_slow_transaction? ? (blockchain.coinbase_slow_amount(block_index, embedded_transactions) + blockchain.total_fees(embedded_transactions)) : blockchain.coinbase_fast_amount(block_index, embedded_transactions)

        if served_sum != served_sum_expected
          raise "invalid served amount for coinbase transaction at index: #{block_index} " +
                "expected #{scale_decimal(served_sum_expected)} but got #{scale_decimal(served_sum)}"
        end
        vt << transaction.as_validated
      rescue e : Exception
        vt << FailedTransaction.new(transaction, e.message || "unknown error", "validate_coinbase").as_validated
      end
      vt
    end

    module Rules
      extend self

      module Sender
        extend self

        def rule_sender_mismatch(transaction : Core::Transaction) : ValidatedTransactions
          transaction.sender_total_amount != transaction.recipient_total_amount ? FailedTransaction.new(transaction, "amount mismatch for senders (#{scale_decimal(transaction.sender_total_amount)}) and recipients (#{scale_decimal(transaction.recipient_total_amount)})", "sender_mismatch").as_validated : transaction.as_validated
        end

        def rule_sender_mismatches(transactions : Array(Core::Transaction)) : ValidatedTransactions
          vt = ValidatedTransactions.empty
          transactions.reject { |t| t.is_coinbase? }.each do |transaction|
            vt << rule_sender_mismatch(transaction)
          end
          vt
        end
      end

      module PrevHash
        extend self

        def rule_coinbase_prev_hash(coinbase_transaction : Core::Transaction) : ValidatedTransactions
          coinbase_transaction.prev_hash != "0" ? FailedTransaction.new(coinbase_transaction, "invalid prev_hash: expected 0 but got #{coinbase_transaction.prev_hash}", "prev_hash").as_validated : coinbase_transaction.as_validated
        end

        def rule_prev_hash(transaction : Core::Transaction, prev_transaction : Core::Transaction) : ValidatedTransactions
          transaction.prev_hash != prev_transaction.to_hash ? FailedTransaction.new(transaction, "invalid prev_hash: expected #{prev_transaction.to_hash} but got #{transaction.prev_hash}", "prev_hash").as_validated : transaction.as_validated
        end

        def rule_prev_hashes(transactions : Array(Core::Transaction)) : ValidatedTransactions
          vt = ValidatedTransactions.empty
          transactions.each_with_index do |transaction, index|
            vt << (transaction.is_coinbase? ? rule_coinbase_prev_hash(transaction) : rule_prev_hash(transaction, transactions[index - 1]))
          end
          vt
        end
      end
    end

    include Logger
  end

  class ValidatedTransactions
    property failed : Array(FailedTransaction)
    property passed : Array(Core::Transaction)

    def initialize(@failed : Array(FailedTransaction), @passed : Array(Core::Transaction))
    end

    def self.empty
      ValidatedTransactions.new([] of FailedTransaction, [] of Core::Transaction)
    end

    def self.passed(transactions : Array(Core::Transaction))
      ValidatedTransactions.new([] of FailedTransaction, transactions)
    end

    def self.failed(transactions : Array(Core::Transaction), reason : String, location : String)
      ValidatedTransactions.new(transactions.map { |t| FailedTransaction.new(t, reason, location) })
    end

    def self.with(failed_transactions : Array(Core::Transaction), reason : String, location : String, passed_transactions : Array(Core::Transaction))
      ValidatedTransactions.new(failed_transactions.map { |t| FailedTransaction.new(t, reason, location) }, passed_transactions)
    end

    def <<(other : ValidatedTransactions) : ValidatedTransactions
      add_passed_unless_dup(other)
      add_failed_unless_dup(other)
      # remove any rejected from passed
      self.passed = self.passed.reject { |t| self.failed.map(&.transaction.id).includes?(t.id) }
      self
    end

    def add_passed_unless_dup(other : ValidatedTransactions)
      # add the new transactions unless already exists or it was already failed
      other.passed.each do |transaction|
        self.passed << transaction unless self.passed.map(&.id).includes?(transaction.id) || self.failed.map(&.transaction.id).includes?(transaction.id)
      end

      # if any of the new transactions are common validated and already stored in passed - updated the stored ones
      # and set them as common validated
      other.passed.select { |t| t.is_common_validated? }.each do |transaction|
        self.passed.each do |validated_transaction|
          validated_transaction.set_common_validated if transaction.is_common_validated?
        end
      end

      # self.passed = self.passed.reject{|t| self.failed.map(&.transaction.id).includes?(t.id)}
    end

    def add_failed_unless_dup(other : ValidatedTransactions)
      # add the new transactions unless already exists
      other.failed.each do |ft|
        self.failed << ft unless self.failed.map(&.transaction.id).includes?(ft.transaction.id)
      end
    end
  end

  class FailedTransaction
    getter transaction : Core::Transaction
    getter reason : String
    getter location : String

    def initialize(@transaction : Core::Transaction, @reason : String, @location : String)
    end

    def as_validated
      ValidatedTransactions.new([self], [] of Core::Transaction)
    end
  end

  struct TransactionWithBlock
    getter transaction : Core::Transaction
    getter block : Int64

    def initialize(@transaction : Core::Transaction, @block : Int64)
    end
  end

  class Transaction
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
      kind: TransactionKind,
      version: TransactionVersion
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
    # property version : TransactionVersion

    setter prev_hash : String
    @common_validated : Bool = false

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

    def as_validated
      ValidatedTransactions.new([] of FailedTransaction, [self])
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
        self.kind,
        self.version
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
