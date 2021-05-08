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

module ::Axentro::Core::TransactionValidator
  extend self

  MESSAGE_SIZE_LIMIT = 512
  TOKEN_SIZE_LIMIT   =  16

  def validate_embedded(transactions : Array(Axentro::Core::Transaction), blockchain : Blockchain, skip_prev_hash_check : Bool = false) : ValidatedTransactions
    vt = ValidatedTransactions.empty

    # (coinbase are validated in validate_coinbase) and are required to pass into dapps (mainly for utxo)
    transactions.select(&.is_coinbase?).each { |tx| vt << tx }

    # only applies to non coinbase transactions and returns all non coinbase transactions
    vt.concat(TransactionValidator::Rules::Sender.rule_sender_mismatches(transactions))

    unless skip_prev_hash_check
      vt.concat(TransactionValidator::Rules::PrevHash.rule_prev_hashes(vt.passed))
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
      network = Keys::Address.from(sender.address, "sender").network
      return FailedTransaction.new(transaction, "sender address: #{sender.address} has wrong network type: #{network[:name]}, this node is running as: #{network_type}") if network[:name] != network_type

      public_key = Keys::PublicKey.new(sender.public_key, network)

      if public_key.address.as_hex != sender.address
        return FailedTransaction.new(transaction, "sender public key mismatch - sender public key: #{public_key.as_hex} is not for sender address: #{sender.address}")
      end

      verbose "unsigned_json: #{transaction.as_unsigned.to_json}"
      verbose "unsigned_json_hash: #{transaction.as_unsigned.to_hash}"
      verbose "public key: #{public_key.as_hex}"
      verbose "signature: #{sender.signature}"

      verify_result = KeyUtils.verify_signature(transaction.as_unsigned.to_hash, sender.signature, public_key.as_hex)

      verbose "verify signature result: #{verify_result}"

      if !verify_result
        return FailedTransaction.new(transaction, "invalid signing for sender: #{sender.address}")
      end

      unless Keys::Address.from(sender.address, "sender")
        return FailedTransaction.new(transaction, "invalid checksum for sender's address: #{sender.address}")
      end

      valid_amount?(sender.amount)
      nil
    end
  end

  def validate_recipients(transaction : Axentro::Core::Transaction, network_type : String)
    transaction.recipients.each do |recipient|
      recipient_address = Keys::Address.from(recipient.address, "recipient")
      unless recipient_address
        return FailedTransaction.new(transaction, "invalid checksum for recipient's address: #{recipient.address}")
      end

      network = recipient_address.network
      return FailedTransaction.new(transaction, "recipient address: #{recipient.address} has wrong network type: #{network[:name]}, this node is running as: #{network_type}") if network[:name] != network_type

      valid_amount?(recipient.amount)
    end
  end

  # ameba:disable Metrics/CyclomaticComplexity
  def validate_common(transactions : Array(Axentro::Core::Transaction), network_type : String) : ValidatedTransactions
    vt = ValidatedTransactions.empty
    transactions.each do |transaction|
      vt << FailedTransaction.new(transaction, "length of transaction id has to be 64: #{transaction.id}") && next if transaction.id.size != 64
      vt << FailedTransaction.new(transaction, "message size exceeds: #{transaction.message.bytesize} for #{MESSAGE_SIZE_LIMIT}") && next if transaction.message.bytesize > MESSAGE_SIZE_LIMIT
      vt << FailedTransaction.new(transaction, "token size exceeds: #{transaction.token.bytesize} for #{TOKEN_SIZE_LIMIT}") && next if transaction.token.bytesize > TOKEN_SIZE_LIMIT
      vt << FailedTransaction.new(transaction, "unscaled transaction") && next if transaction.scaled != 1
      vt << FailedTransaction.new(transaction, "action must not be empty") && next if transaction.action.empty?

      # TODO - validate transaction id is not already in db or in current batch of transactions

      if !DApps::ASSET_ACTIONS.includes?(transaction.action) && transaction.assets.size > 0
        vt << FailedTransaction.new(transaction, "assets must be empty for supplied action: #{transaction.action}")
        next
      end

      if transaction.modules.size > 0
        vt << FailedTransaction.new(transaction, "modules must be empty as still in development")
      end

      if transaction.inputs.size > 0
        vt << FailedTransaction.new(transaction, "inputs must be empty as still in development")
      end

      if transaction.outputs.size > 0
        vt << FailedTransaction.new(transaction, "outputs must be empty as still in development")
      end

      if transaction.linked != ""
        vt << FailedTransaction.new(transaction, "linked must be empty as still in development")
      end

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

  # ameba:disable Metrics/CyclomaticComplexity
  def validate_coinbase(coinbase_transactions : Array(Axentro::Core::Transaction), embedded_transactions : Array(Axentro::Core::Transaction), blockchain : Blockchain, block_index : Int64) : ValidatedTransactions
    vt = ValidatedTransactions.empty
    coinbase_transactions.each do |transaction|
      vt << FailedTransaction.new(transaction, "actions has to be 'head' for coinbase transaction") && next if transaction.action != "head"
      vt << FailedTransaction.new(transaction, "message has to be '0' for coinbase transaction") && next if transaction.message != "0"
      vt << FailedTransaction.new(transaction, "token has to be #{TOKEN_DEFAULT} for coinbase transaction") && next if transaction.token != TOKEN_DEFAULT
      vt << FailedTransaction.new(transaction, "there should be no Sender for a coinbase transaction") && next if transaction.senders.size != 0
      vt << FailedTransaction.new(transaction, "prev_hash of coinbase transaction has to be '0'") && next if transaction.prev_hash != "0"

      served_sum = transaction.recipients.reduce(0_i64) { |sum, recipient| sum + recipient.amount }
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

      def rule_sender_mismatch(transaction : Axentro::Core::Transaction)
        transaction.sender_total_amount != transaction.recipient_total_amount ? FailedTransaction.new(transaction, "amount mismatch for senders (#{scale_decimal(transaction.sender_total_amount)}) and recipients (#{scale_decimal(transaction.recipient_total_amount)})") : transaction
      end

      def rule_sender_mismatches(transactions : Array(Axentro::Core::Transaction)) : ValidatedTransactions
        vt = ValidatedTransactions.empty
        transactions.reject(&.is_coinbase?).each do |transaction|
          vt << rule_sender_mismatch(transaction)
        end
        vt
      end
    end

    module PrevHash
      extend self

      def rule_coinbase_prev_hash(coinbase_transaction : Axentro::Core::Transaction)
        coinbase_transaction.prev_hash != "0" ? FailedTransaction.new(coinbase_transaction, "invalid prev_hash: expected 0 but got #{coinbase_transaction.prev_hash}") : coinbase_transaction
      end

      def rule_prev_hash(transaction : Axentro::Core::Transaction, prev_transaction : Axentro::Core::Transaction)
        transaction.prev_hash != prev_transaction.to_hash ? FailedTransaction.new(transaction, "invalid prev_hash: expected #{prev_transaction.to_hash} but got #{transaction.prev_hash}") : transaction
      end

      def rule_prev_hashes(transactions : Array(Axentro::Core::Transaction))
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
  getter passed : Array(Axentro::Core::Transaction)

  def initialize(@failed, @passed)
  end

  def self.empty
    ValidatedTransactions.new(Array(FailedTransaction).new, Array(Axentro::Core::Transaction).new)
  end

  def self.with(failed_transactions : Array(Axentro::Core::Transaction), reason : String, passed_transactions : Array(Axentro::Core::Transaction))
    ValidatedTransactions.new(failed_transactions.map { |t| FailedTransaction.new(t, reason) }, passed_transactions)
  end

  def self.passed(transactions : Array(Axentro::Core::Transaction))
    ValidatedTransactions.new([] of FailedTransaction, transactions)
  end

  def <<(failed_tx : FailedTransaction)
    failed << failed_tx
    passed.delete(failed_tx.transaction)
    self
  end

  def <<(tx : Axentro::Core::Transaction)
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
    other.passed.select(&.is_common_validated?).each do |transaction|
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
  getter transaction : Axentro::Core::Transaction
  getter reason : String

  def initialize(@transaction, @reason : String)
  end
end

struct TransactionWithBlock
  getter transaction : Axentro::Core::Transaction
  getter block : Int64

  def initialize(@transaction, @block)
  end
end
