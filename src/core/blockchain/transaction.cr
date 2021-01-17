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
      transactions.select(&.is_coinbase?).each { |tx| vt << tx }

      # only applies to non coinbase transactions and returns all non coinbase transactions
      vt.concat(Validation::Transaction::Rules::Sender.rule_sender_mismatches(transactions))

      unless skip_prev_hash_check
        vt.concat(Validation::Transaction::Rules::PrevHash.rule_prev_hashes(vt.passed))
      end

      blockchain.dapps.each do |dapp|
        related_transactions = vt.passed.select { |t| dapp.transaction_related?(t.action) }
        if related_transactions.size > 0
          vt.concat(dapp.valid?(related_transactions))
        end
      end

      vt
    end

    def validate_senders(transaction : Axentro::Core::Transaction, network_type : String)
      transaction.senders.each do |sender|
        network = Keys::Address.from(sender[:address], "sender").network
        return FailedTransaction.new(transaction, "sender address: #{sender[:address]} has wrong network type: #{network[:name]}, this node is running as: #{network_type}") if network[:name] != network_type

        public_key = Keys::PublicKey.new(sender[:public_key], network)

        if public_key.address.as_hex != sender[:address]
          return FailedTransaction.new(transaction, "sender public key mismatch - sender public key: #{public_key.as_hex} is not for sender address: #{sender[:address]}")
        end

        verbose "unsigned_json: #{transaction.as_unsigned.to_json}"
        verbose "unsigned_json_hash: #{transaction.as_unsigned.to_hash}"
        verbose "public key: #{public_key.as_hex}"
        verbose "signature: #{sender[:signature]}"

        verify_result = KeyUtils.verify_signature(transaction.as_unsigned.to_hash, sender[:signature], public_key.as_hex)

        verbose "verify signature result: #{verify_result}"

        if !verify_result
          return FailedTransaction.new(transaction, "invalid signing for sender: #{sender[:address]}")
        end

        unless Keys::Address.from(sender[:address], "sender")
          return FailedTransaction.new(transaction, "invalid checksum for sender's address: #{sender[:address]}")
        end

        valid_amount?(sender[:amount])
        nil
      end
    end

    def validate_recipients(transaction : Core::Transaction, network_type : String)
      transaction.recipients.each do |recipient|
        recipient_address = Keys::Address.from(recipient[:address], "recipient")
        unless recipient_address
          return FailedTransaction.new(transaction, "invalid checksum for recipient's address: #{recipient[:address]}")
        end

        network = recipient_address.network
        return FailedTransaction.new(transaction, "recipient address: #{recipient[:address]} has wrong network type: #{network[:name]}, this node is running as: #{network_type}") if network[:name] != network_type

        valid_amount?(recipient[:amount])
      end
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def validate_common(transactions : Array(Core::Transaction), network_type : String) : ValidatedTransactions
      vt = ValidatedTransactions.empty
      transactions.each do |transaction|
        vt << FailedTransaction.new(transaction, "length of transaction id has to be 64: #{transaction.id}") && next if transaction.id.size != 64
        vt << FailedTransaction.new(transaction, "message size exceeds: #{transaction.message.bytesize} for #{MESSAGE_SIZE_LIMIT}") && next if transaction.message.bytesize > MESSAGE_SIZE_LIMIT
        vt << FailedTransaction.new(transaction, "token size exceeds: #{transaction.token.bytesize} for #{TOKEN_SIZE_LIMIT}") && next if transaction.token.bytesize > TOKEN_SIZE_LIMIT
        vt << FailedTransaction.new(transaction, "unscaled transaction") && next if transaction.scaled != 1

        if failed_transaction = validate_senders(transaction, network_type)
          vt << failed_transaction
          next
        end

        if failed_transaction = validate_recipients(transaction, network_type)
          vt << failed_transaction
          next
        end

        transaction = transaction.set_common_validated
        vt << transaction
      rescue e : Axentro::Common::AxentroException
        vt << FailedTransaction.new(transaction, e.message || "unknown error")
      rescue e : Exception
        vt << FailedTransaction.new(transaction, "unexpected error")
        error("#{e.class}: #{e.message || "unknown error"}\n#{e.backtrace.join("\n")}")
      end
      vt
    end

    def validate_coinbase(coinbase_transactions : Array(Core::Transaction), embedded_transactions : Array(Core::Transaction), blockchain : Blockchain, block_index : Int64) : ValidatedTransactions
      vt = ValidatedTransactions.empty
      coinbase_transactions.each do |transaction|
        vt << FailedTransaction.new(transaction, "actions has to be 'head' for coinbase transaction") && next if transaction.action != "head"
        vt << FailedTransaction.new(transaction, "message has to be '0' for coinbase transaction") && next if transaction.message != "0"
        vt << FailedTransaction.new(transaction, "token has to be #{TOKEN_DEFAULT} for coinbase transaction") && next if transaction.token != TOKEN_DEFAULT
        vt << FailedTransaction.new(transaction, "there should be no Sender for a coinbase transaction") && next if transaction.senders.size != 0
        vt << FailedTransaction.new(transaction, "prev_hash of coinbase transaction has to be '0'") && next if transaction.prev_hash != "0"

        served_sum = transaction.recipients.reduce(0_i64) { |sum, recipient| sum + recipient[:amount] }
        served_sum_expected = transaction.is_slow_transaction? ? (blockchain.coinbase_slow_amount(block_index, embedded_transactions) + blockchain.total_fees(embedded_transactions)) : blockchain.coinbase_fast_amount(block_index, embedded_transactions)

        if served_sum != served_sum_expected
          vt << FailedTransaction.new(transaction, "invalid served amount for coinbase transaction at index: #{block_index} " +
                "expected #{scale_decimal(served_sum_expected)} but got #{scale_decimal(served_sum)}")
          next
        end
        vt << transaction
      rescue e : Axentro::Common::AxentroException
        vt << FailedTransaction.new(transaction, e.message || "unknown error")
      rescue e : Exception
        vt << FailedTransaction.new(transaction, "unexpected error")
        error("#{e.class}: #{e.message || "unknown error"}\n#{e.backtrace.join("\n")}")
      end
      vt
    end

    module Rules
      extend self

      module Sender
        extend self

        def rule_sender_mismatch(transaction : Core::Transaction)
          transaction.sender_total_amount != transaction.recipient_total_amount ? FailedTransaction.new(transaction, "amount mismatch for senders (#{scale_decimal(transaction.sender_total_amount)}) and recipients (#{scale_decimal(transaction.recipient_total_amount)})") : transaction
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

        def rule_coinbase_prev_hash(coinbase_transaction : Core::Transaction)
          coinbase_transaction.prev_hash != "0" ? FailedTransaction.new(coinbase_transaction, "invalid prev_hash: expected 0 but got #{coinbase_transaction.prev_hash}") : coinbase_transaction
        end

        def rule_prev_hash(transaction : Core::Transaction, prev_transaction : Core::Transaction)
          transaction.prev_hash != prev_transaction.to_hash ? FailedTransaction.new(transaction, "invalid prev_hash: expected #{prev_transaction.to_hash} but got #{transaction.prev_hash}") : transaction
        end

        def rule_prev_hashes(transactions : Array(Core::Transaction))
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
    getter failed : Array(FailedTransaction)
    getter passed : Array(Core::Transaction)

    def initialize(@failed, @passed)
    end

    def self.empty
      ValidatedTransactions.new(Array(FailedTransaction).new,Array(Core::Transaction).new)
    end

    def self.with(failed_transactions : Array(Core::Transaction), reason : String, passed_transactions : Array(Core::Transaction))
      ValidatedTransactions.new(failed_transactions.map { |t| FailedTransaction.new(t, reason) }, passed_transactions)
    end

    def self.passed(transactions : Array(Core::Transaction))
      ValidatedTransactions.new([] of FailedTransaction, transactions)
    end

    def <<(failed_tx : FailedTransaction)
      failed << failed_tx
      passed.delete(failed_tx.transaction)
      self
    end

    def <<(tx : Transaction)
      passed << tx
      self
    end

    def concat(other : ValidatedTransactions) : ValidatedTransactions
      add_passed_unless_dup(other)
      add_failed_unless_dup(other)
      # remove any rejected from passed
      failed.each { |failed_tx| passed.delete(failed_tx.transaction) }
      self
    end

    private def add_passed_unless_dup(other : ValidatedTransactions)
      # add the new transactions unless already exists or it was already failed
      other.passed.each do |transaction|
        passed << transaction unless passed.map(&.id).includes?(transaction.id) || failed.map(&.transaction.id).includes?(transaction.id)
      end

      # if any of the new transactions are common validated and already stored in passed - updated the stored ones
      # and set them as common validated
      other.passed.select { |t| t.is_common_validated? }.each do |transaction|
        passed.each do |validated_transaction|
          validated_transaction.set_common_validated if transaction.is_common_validated?
        end
      end
    end

    private def add_failed_unless_dup(other : ValidatedTransactions)
      # add the new transactions unless already exists
      other.failed.each do |ft|
        failed << ft unless failed.map(&.transaction.id).includes?(ft.transaction.id)
      end
    end
  end

  class FailedTransaction
    getter transaction : Core::Transaction
    getter reason : String

    def initialize(@transaction, @reason : String)
    end
  end

  struct TransactionWithBlock
    getter transaction : Core::Transaction
    getter block : Int64

    def initialize(@transaction, @block)
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
