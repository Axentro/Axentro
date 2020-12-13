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
require "../../node/*"
require "../../dapps/dapp"
require "../../dapps/build_in/rejects"

module ::Axentro::Core::FastChain
  alias FastHeader = NamedTuple(
    index: Int64,
    prev_hash: String,
    merkle_tree_root: String,
    timestamp: Int64,
  )

  def process_fast_transactions
    loop do
      spawn do
        if node.i_am_a_fast_node?
          begin
            debug "********** process fast transactions ***********"
            if pending_fast_transactions.size > 0
              debug "There are #{pending_fast_transactions.size} pending fast transactions"
              valid_transactions = valid_transactions_for_fast_block

              if valid_transactions[:transactions].size > 1
                debug "There are #{valid_transactions.size} valid fast transactions so mint a new fast block"

                block = mint_fast_block(valid_transactions)
                # if block.valid?(self)
                debug "record new fast block"
                node.new_block(block)
                debug "broadcast new fast block"
                node.send_block(block)
                # end
              end
            end
          rescue e : Exception
            error e.message.not_nil!
          end
        end
      end
      sleep 2
    end
  end

  def latest_fast_block : FastBlock?
    fast_blocks = @chain.select(&.is_fast_block?)
    (fast_blocks.size > 0) ? fast_blocks.last.as(FastBlock) : nil
  end

  def latest_fast_block_index_or_zero : Int64
    fast_blocks = @chain.select(&.is_fast_block?)
    (fast_blocks.size > 0) ? fast_blocks.last.as(FastBlock).index : 0_i64
  end

  def get_latest_index_for_fast
    index = latest_fast_block_index_or_zero
    index.odd? ? index + 2 : index + 1
  end

  def valid_transactions_for_fast_block
    latest_index = get_latest_index_for_fast
    coinbase_amount = coinbase_fast_amount(latest_index, embedded_fast_transactions)
    coinbase_transaction = create_coinbase_fast_transaction(coinbase_amount)
    {latest_index: latest_index, transactions: align_fast_transactions(coinbase_transaction, coinbase_amount, embedded_fast_transactions)}
  end

  def mint_fast_block(valid_transactions)
    transactions = valid_transactions[:transactions]
    latest_index = valid_transactions[:latest_index]
    debug "minting fast block #{latest_index}"
    _latest_block = latest_fast_block || get_genesis_block
    timestamp = __timestamp

    wallet = node.get_wallet
    address = wallet.address
    public_key = wallet.public_key
    latest_block_hash = _latest_block.to_hash

    hash = FastBlock.to_hash(latest_index, transactions, latest_block_hash, address, public_key)
    private_key = Wif.new(wallet.wif).private_key.as_hex
    signature = KeyUtils.sign(private_key, hash)

    FastBlock.new(
      latest_index,
      transactions,
      latest_block_hash,
      timestamp,
      address,
      public_key,
      signature,
      hash
    )
  end

  def align_fast_transactions(coinbase_transaction : Transaction, coinbase_amount : Int64, embedded_fast_transactions : Array(Transaction)) : Transactions
    transactions = [coinbase_transaction] + embedded_fast_transactions

    vt = Validation::Transaction.validate_common(transactions, @network_type)
    block_index = latest_fast_block.nil? ? 0_i64 : latest_fast_block.not_nil!.index

    # don't validate prev hash here as we haven't assigned them yet. We assign lower down after we have all the valid transactions
    skip_prev_hash_check = true
    vt << Validation::Transaction.validate_embedded(transactions, self, skip_prev_hash_check)

    vt.failed.each do |ft|
      rejects.record_reject(ft.transaction.id, Rejects.address_from_senders(ft.transaction.senders), ft.reason)
      node.wallet_info_controller.update_wallet_information([ft.transaction])
      FastTransactionPool.delete(ft.transaction)
    end

    # validate coinbase and fix it if incorrect (due to rejected transactions)
    vtc = Validation::Transaction.validate_coinbase([coinbase_transaction], vt.passed, self, block_index)
    aligned_transactions = if vtc.failed.size == 0
                             vt.passed
                           else
                             coinbase_amount = coinbase_fast_amount(block_index, vt.passed)
                             coinbase_transaction = create_coinbase_fast_transaction(coinbase_amount)
                             [coinbase_transaction] + vt.passed.reject(&.is_coinbase?)
                           end

    sorted_aligned_transactions = [coinbase_transaction] + aligned_transactions.reject(&.is_coinbase?).sort_by(&.timestamp)
    sorted_aligned_transactions.map_with_index do |transaction, index|
      transaction.add_prev_hash((index == 0 ? "0" : sorted_aligned_transactions[index - 1].to_hash))
    end
  end

  def create_coinbase_fast_transaction(coinbase_amount : Int64) : Transaction
    node_reccipient = {
      address: @wallet.address,
      amount:  coinbase_amount,
    }

    senders = [] of Transaction::Sender # No senders

    recipients = coinbase_amount > 0 ? [node_reccipient] : [] of Transaction::Recipient

    Transaction.new(
      Transaction.create_id,
      "head",
      senders,
      recipients,
      "0",           # message
      TOKEN_DEFAULT, # token
      "0",           # prev_hash
      __timestamp,   # timestamp
      1,             # scaled
      TransactionKind::FAST,
      TransactionVersion::V1
    )
  end

  def coinbase_fast_amount(index : Int64, transactions) : Int64
    total_fees(transactions)
  end

  def replace_fast_transactions(transactions : Array(Transaction))
    results = FastTransactionPool.find_all(transactions.select(&.is_fast_transaction?))
    fast_transactions = results.found + results.not_found

    vt = Validation::Transaction.validate_common(fast_transactions, @network_type)

    vt.failed.each do |ft|
      rejects.record_reject(ft.transaction.id, Rejects.address_from_senders(ft.transaction.senders), ft.reason)
      node.wallet_info_controller.update_wallet_information([ft.transaction])
    end

    FastTransactionPool.lock
    FastTransactionPool.replace(vt.passed)
  end

  def clean_fast_transactions
    debug "inside clean fast transactions"
    FastTransactionPool.lock
    debug "locked FastTransactionPool"
    transactions = pending_fast_transactions.reject { |t| indices.get(t.id) }.select(&.is_fast_transaction?)
    debug "filter out transactions in indices: #{transactions.size}"
    FastTransactionPool.replace(transactions)
    debug "replace transactions in pool: #{FastTransactionPool.all.size}"
  end

  def clean_fast_transactions_used_in_block(block : FastBlock)
    FastTransactionPool.lock
    transactions = pending_fast_transactions.reject { |t| block.find_transaction(t.id) == true }.select(&.is_fast_transaction?)
    FastTransactionPool.replace(transactions)
  end

  def push_fast_block(block : FastBlock)
    _push_block(block)
    clean_fast_transactions

    block
  end

  include Block
  include ::Axentro::Core::DApps::BuildIn
end
