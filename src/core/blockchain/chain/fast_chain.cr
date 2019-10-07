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

module ::Sushi::Core::FastChain
  alias FastHeader = NamedTuple(
    index: Int64,
    prev_hash: String,
    merkle_tree_root: String,
    timestamp: Int64,
  )

  private def get_ranking(address)
    Ranking.rank(address, Ranking.chain(chain))
  end

  private def i_can_lead?(my_ranking)
    return false if node.is_private_node?
    my_ranking > 0
  end

  private def assume_leadership
    info "Assuming leadership role because I'm ranked high enough"
    node.set_current_leader(CurrentLeader.new(node.get_node_id, node.get_wallet.address))
    debug "current_leader_in_contest: #{node.get_current_leader}"
  end

  # TODO - include node_id so that we don't have mulitple leaders if using the same wallet address
  # when a node comes online have it broadcast it's ranking and take over leadership if able
  # restrict the ranking check to the last couple days worth of chain blocks
  private def leadership_contest
    loop do
      if chain_mature_enough_for_fast_blocks?
        my_ranking = get_ranking(node.get_wallet.address)

        if node.has_no_connections?
          if i_can_lead?(my_ranking)
            debug "setting this node as leader as has no connections and is a high enough rank for this chain"
            node.set_current_leader(CurrentLeader.new(node.get_node_id, node.get_wallet.address))
          end
        else
          if (Time.now - node.get_last_heartbeat) > 2.seconds # && i_am_not_the_current_leader
            debug "Heartbeat not received within 2 second timeout - trying to assume leadership"
            if i_can_lead?(my_ranking)
              assume_leadership
            else
              debug "I'm not ranked high enough on this chain to become a leader"
            end
          end
        end
      end
      sleep 2
    end
  end

  private def i_am_not_the_current_leader
    !i_am_the_current_leader
  end

  private def i_am_the_current_leader
    CurrentLeader.new(node.get_node_id, node.get_wallet.address) == node.get_current_leader
  end

  private def broadcast_heartbeat
    wallet = node.get_wallet
    address = wallet.address
    node_id = node.get_node_id
    public_key = wallet.public_key
    hash_salt = sha256(node.get_heartbeat_salt + public_key)
    private_key = Wif.new(wallet.wif).private_key.as_hex

    sig = ECCrypto.sign(private_key, hash_salt)
    node.broadcast_heartbeat(address, node_id, public_key, hash_salt, sig["r"], sig["s"])
  end

  def process_fast_transactions
    loop do
      if chain_mature_enough_for_fast_blocks? && i_am_the_current_leader
        begin
          broadcast_heartbeat unless node.has_no_connections?

          debug "********** process fast transactions ***********"
          if pending_fast_transactions.size > 0
            debug "There are #{pending_fast_transactions.size} pending fast transactions"
            valid_transactions = valid_transactions_for_fast_block

            if valid_transactions[:transactions].size > 1
              debug "There are #{valid_transactions.size} valid fast transactions so mint a new fast block"

              block = mint_fast_block(valid_transactions)
              if block.valid?(self)
                debug "record new fast block"
                node.new_block(block)
                debug "broadcast new fast block"
                node.send_block(block)
              end
            end
          end
        rescue e : Exception
          error e.message.not_nil!
        end
      end
      sleep 2
    end
  end

  def chain_mature_enough_for_fast_blocks?
    return true if node.has_no_connections? && !node.is_private_node?
    return true if ENV.has_key?("SC_UNIT") || ENV.has_key?("SC_INTEGRATION") || ENV.has_key?("SC_E2E") || ENV.has_key?("SC_FAST")
    get_latest_index_for_slow > 1440_i64
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
    @chain.select(&.is_fast_block?).select{|block| block.index > from}
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
    _latest_block = latest_fast_block || get_genesis_block
    timestamp = __timestamp

    wallet = node.get_wallet
    address = wallet.address
    public_key = wallet.public_key
    hash_salt = sha256(node.get_heartbeat_salt + public_key)
    private_key = Wif.new(wallet.wif).private_key.as_hex

    sig = ECCrypto.sign(private_key, hash_salt)

    FastBlock.new(
      latest_index,
      transactions,
      _latest_block.to_hash,
      timestamp,
      address,
      public_key,
      sig["r"],
      sig["s"],
      hash_salt
    )
  end

  def align_fast_transactions(coinbase_transaction : Transaction, coinbase_amount : Int64) : Transactions
    aligned_transactions = [coinbase_transaction]

    debug "entered align_fast_transactions with embedded_fast_transactions size: #{embedded_fast_transactions.size}"
    embedded_fast_transactions.each do |t|
      t.prev_hash = aligned_transactions[-1].to_hash
      t.valid_as_embedded?(self, aligned_transactions)

      aligned_transactions << t
    rescue e : Exception
      debug "align_fast_transactions: REJECTED transaction due to #{e}"
      rejects.record_reject(t.id, e)

      FastTransactionPool.delete(t)
    end
    debug "exited align_fast_transactions with embedded_fast_transactions size: #{embedded_fast_transactions.size}"

    aligned_transactions
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
      TransactionKind::FAST
    )
  end

  def coinbase_fast_amount(index : Int64, transactions) : Int64
    total_fees(transactions)
  end

  def replace_fast_transactions(transactions : Array(Transaction))
    transactions = transactions.select(&.is_fast_transaction?)
    replace_transactions = [] of Transaction

    transactions.each_with_index do |t, i|
      progress "validating fast transaction #{t.short_id}", i + 1, transactions.size

      t = FastTransactionPool.find(t) || t
      t.valid_common?

      replace_transactions << t
    rescue e : Exception
      rejects.record_reject(t.id, e)
    end

    FastTransactionPool.lock
    FastTransactionPool.replace(replace_transactions)
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

  def push_fast_block(block : FastBlock)
    _push_block(block)
    clean_fast_transactions

    block
  end

  include Block
end
