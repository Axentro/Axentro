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

  def subchain_fast(from : Int64) : Chain
    @database.get_fast_blocks(from)
  end

  def valid_transactions_for_fast_block
    latest_index = get_latest_index_for_fast
    coinbase_amount = coinbase_fast_amount(latest_index, embedded_fast_transactions)
    coinbase_transaction = create_coinbase_fast_transaction(coinbase_amount)
    {latest_index: latest_index, transactions: align_fast_transactions(coinbase_transaction, coinbase_amount)}
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

  def align_fast_transactions(coinbase_transaction : Transaction, coinbase_amount : Int64) : Transactions
    transactions = [coinbase_transaction] + embedded_fast_transactions

    puts "ALIGN_FAST_TRANSACTIONS quantity: #{transactions.size}"

    vt = Validation::Transaction.validate_common(transactions)
    skip_prev_hash_check = true
    vt << Validation::Transaction.validate_embedded(transactions, self, skip_prev_hash_check)

    vt.failed.each do |ft|
      rejects.record_reject(ft.transaction.id, Rejects.address_from_senders(ft.transaction.senders), ft.reason)
      node.wallet_info_controller.update_wallet_information([ft.transaction])
      FastTransactionPool.delete(ft.transaction)
    end

    vt.passed.map_with_index do |transaction, index|
      transaction.add_prev_hash((index == 0 ? "0" : vt.passed[index - 1].to_hash))
    end
  end

  # def align_fast_transactions(coinbase_transaction : Transaction, coinbase_amount : Int64) : Transactions
  #   aligned_transactions = [coinbase_transaction]

  #   debug "entered align_fast_transactions with embedded_fast_transactions size: #{embedded_fast_transactions.size}"
  #   embedded_fast_transactions.each do |t|
  #     t.prev_hash = aligned_transactions[-1].to_hash
  #     t.valid_as_embedded?(self, aligned_transactions)
  #     aligned_transactions << t
  #   rescue e : Exception
  #     debug "align_fast_transactions: REJECTED transaction due to #{e}"
  #     rejects.record_reject(t.id, Rejects.address_from_senders(t.senders), e)
  #     node.wallet_info_controller.update_wallet_information([t])

  #     FastTransactionPool.delete(t)
  #   end
  #   debug "exited align_fast_transactions with embedded_fast_transactions size: #{embedded_fast_transactions.size}"

  #   aligned_transactions
  # end

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
      TransactionKind::FAST
    )
  end

  def coinbase_fast_amount(index : Int64, transactions) : Int64
    total_fees(transactions)
  end

  # def replace_fast_transactions(transactions : Array(Transaction))
  #   transactions = transactions.select(&.is_fast_transaction?)
  #   replace_transactions = [] of Transaction

  #   transactions.each_with_index do |t, i|
  #     progress "validating fast transaction #{t.short_id}", i + 1, transactions.size

  #     t = FastTransactionPool.find(t) || t
  #     t.valid_common?

  #     replace_transactions << t
  #   rescue e : Exception
  #     rejects.record_reject(t.id, Rejects.address_from_senders(t.senders), e)
  #     node.wallet_info_controller.update_wallet_information([t])
  #   end

  #   FastTransactionPool.lock
  #   FastTransactionPool.replace(replace_transactions)
  # end

  def replace_fast_transactions(transactions : Array(Transaction))
    results = FastTransactionPool.find_all(transactions.select(&.is_fast_transaction?))
    fast_transactions = results.found + results.not_found

    vt = Validation::Transaction.validate_common(fast_transactions)

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
