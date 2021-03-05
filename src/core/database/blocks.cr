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
require "../blockchain/*"
require "../blockchain/domain_model/*"

module ::Axentro::Core::Data::Blocks
  # ------- Definition -------
  def block_insert_fields_string : String
    "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
  end

  # ------- Insert -------
  def block_insert_values_array(block : Block) : Array(DB::Any)
    ary = [] of DB::Any
    ary << block.index << block.nonce.to_s << block.prev_hash << block.timestamp << block.difficulty << block.address << block.kind.to_s << block.public_key << block.signature << block.hash << block.version << block.hash_version << block.merkle_tree_root
    ary
  end

  def push_block(block : Block)
    verbose "database.push_block with block index #{block.index} of kind: #{block.kind}"
    @db.exec "BEGIN TRANSACTION"
    block.transactions.each_with_index do |t, ti|
      verbose "writing transaction #{ti} to database with short ID of #{t.short_id}" if ti < 4
      t.senders.each_index do |i|
        @db.exec "insert into senders values (#{sender_insert_fields_string})", args: sender_insert_values_array(block, t, i)
      end
      t.recipients.each_index do |i|
        @db.exec "insert into recipients values (#{recipient_insert_fields_string})", args: recipient_insert_values_array(block, t, i)
      end
      @db.exec "insert into transactions values (#{transaction_insert_fields_string})", args: transaction_insert_values_array(t, ti, block.index)
    end
    verbose "inserting block with #{block.transactions.size} transactions into database with index: #{block.index}"
    @db.exec "insert into blocks values (#{block_insert_fields_string})", args: block_insert_values_array(block)
    @db.exec "END TRANSACTION"
  rescue e : Exception
    warning "Rolling back db due to error when pushing block to database with message: #{e.message || "unknown"}"
    @db.exec("ROLLBACK")
  end

  # ------- Query -------
  def get_blocks_via_query(the_query, *args) : Blockchain::Chain
    blocks : Blockchain::Chain = [] of Block
    @db.query(the_query, args: args.to_a) do |rows|
      rows.each do
        idx = rows.read(Int64)
        nonce = rows.read(String)
        prev_hash = rows.read(String)
        timestamp = rows.read(Int64)
        diffculty = rows.read(Int32)
        address = rows.read(String)
        kind_string = rows.read(String)
        public_key = rows.read(String)
        signature = rows.read(String)
        hash = rows.read(String)
        version = rows.read(String)
        hash_version = rows.read(String)
        merkle_tree_root = rows.read(String)
        blocks << Block.new(idx, [] of Transaction, nonce, prev_hash, timestamp, diffculty, BlockKind.parse(kind_string), address, public_key, signature, hash, version, hash_version, merkle_tree_root)
      end
    end

    blocks.each do |block|
      block.set_transactions(get_all_transactions(block.index))
    end

    blocks
  end

  def validate_local_db_blocks
    max_slow = highest_index_of_kind(BlockKind::SLOW)
    max_fast = highest_index_of_kind(BlockKind::FAST)

    @db.transaction do |tx|
      conn = tx.connection
      prev_slow_block : Block? = nil
      prev_fast_block : Block? = nil
      conn.query("select * from blocks order by timestamp asc") do |block_rows|
        block_rows.each do
          b_idx = block_rows.read(Int64)
          b_nonce = block_rows.read(String)
          b_prev_hash = block_rows.read(String)
          b_timestamp = block_rows.read(Int64)
          b_diffculty = block_rows.read(Int32)
          b_address = block_rows.read(String)
          b_kind_string = block_rows.read(String)
          b_public_key = block_rows.read(String)
          b_signature = block_rows.read(String)
          b_hash = block_rows.read(String)
          b_version = block_rows.read(String)
          b_hash_version = block_rows.read(String)
          b_merkle_tree_root = block_rows.read(String)

          transactions = [] of Transaction

          conn.query("select * from transactions where block_id = ? order by idx asc", b_idx) do |txn_rows|
            txn_rows.each do
              t_id = txn_rows.read(String)
              txn_rows.read(Int32)
              txn_rows.read(Int64)
              t_action = txn_rows.read(String)
              t_message = txn_rows.read(String)
              t_token = txn_rows.read(String)
              t_prev_hash = txn_rows.read(String)
              t_timestamp = txn_rows.read(Int64)
              t_scaled = txn_rows.read(Int32)
              t_kind_string = txn_rows.read(String)
              t_kind = t_kind_string == "SLOW" ? TransactionKind::SLOW : TransactionKind::FAST
              t_version_string = txn_rows.read(String)
              t_version = TransactionVersion.parse(t_version_string)

              recipients = [] of Transaction::Recipient
              conn.query("select * from recipients where transaction_id = ? order by idx", t_id) do |rec_rows|
                rec_rows.each do
                  rec_rows.read(String)
                  rec_rows.read(Int64)
                  rec_rows.read(Int32)
                  recipients << {
                    address: rec_rows.read(String),
                    amount:  rec_rows.read(Int64),
                  }
                end
              end

              senders = [] of Transaction::Sender
              conn.query("select * from senders where transaction_id = ? order by idx", t_id) do |snd_rows|
                snd_rows.each do
                  snd_rows.read(String?)
                  snd_rows.read(Int64)
                  snd_rows.read(Int32)
                  senders << {
                    address:    snd_rows.read(String),
                    public_key: snd_rows.read(String),
                    amount:     snd_rows.read(Int64),
                    fee:        snd_rows.read(Int64),
                    signature:  snd_rows.read(String),
                  }
                end
              end

              t = Transaction.new(t_id, t_action, senders, recipients, t_message, t_token, t_prev_hash, t_timestamp, t_scaled, t_kind, t_version)
              transactions << t
            end

            block = Block.new(b_idx, transactions, b_nonce, b_prev_hash, b_timestamp, b_diffculty, BlockKind.parse(b_kind_string), b_address, b_public_key, b_signature, b_hash, b_version, b_hash_version, b_merkle_tree_root)

            if prev_slow_block
              if block.kind == "SLOW"
                progress("block ##{block.index} was validated", block.index, max_slow)
                BlockValidator.quick_validate(block, prev_slow_block)
              end
            end

            if prev_fast_block
              if block.kind == "FAST"
                progress("block ##{block.index} was validated", block.index, max_fast)
                BlockValidator.quick_validate(block, prev_fast_block)
              end
            end

            if block.kind == "SLOW"
              prev_slow_block = block
            else
              prev_fast_block = block
            end
          end
        end
      end
    end
  end

  def get_block(index : Int64) : Block?
    verbose "Reading block from the database for block #{index}"
    block : Block? = nil
    blocks = get_blocks_via_query("select * from blocks where idx = ?", index)
    block = blocks[0] if blocks.size > 0
    block
  end

  def get_previous_slow_from(index : Int64) : Block?
    block : Block? = nil
    blocks = get_blocks_via_query("select * from blocks where idx <= ? and kind = 'SLOW' order by idx desc limit 1", index)
    block = blocks[0].as(Block) if blocks.size > 0
    block
  end

  def get_highest_block_for_kind(kind : BlockKind)
    get_blocks_via_query("select * from blocks where idx in (select max(idx) from blocks where kind = ?)", kind.to_s)
  end

  def get_block_for_transaction(transaction_id : String) : Block?
    verbose "Reading block from the database for transaction #{transaction_id}"
    block : Block? = nil
    blocks = get_blocks_via_query(
      "select * from blocks where idx in " \
      "(select block_id from transactions where id = ?)",
      transaction_id)
    block = blocks[0] if blocks.size > 0
    block
  end

  def chunk_from(start_index : Int64, chunk_size : Int32) : Blockchain::Chain
    get_blocks_via_query("select * from blocks where timestamp >= (select timestamp from blocks where idx = ?) order by timestamp asc limit ?", start_index, chunk_size)
  end

  def get_blocks_by_ids(ids : Array(Int64)) : Blockchain::Chain
    index_list = ids.map(&.to_s).join(",")
    get_blocks_via_query("select * from blocks where idx in (#{index_list})")
  end

  def total_blocks : Int32
    @db.query_one("select count(*) from blocks", as: Int32)
  end

  def do_i_have_block(index : Int64) : Bool
    result = @db.query_one("select count(*) from blocks where idx = ? limit 1", index, as: Int64)
    result > 0_i64
  end

  # ------- Archive ------
  def archive_block(index : Int64, block_hash : String, reason : String) # reason: restore or sync
    now = __timestamp
    @db.exec "BEGIN TRANSACTION"
    @db.exec "insert or replace into archived_blocks select ?, ?, ?, * from blocks where idx = ?", args: [block_hash, now, reason, index]
    @db.exec "insert or replace into archived_transactions select ?, ?, ?, * from transactions where block_id = ?", args: [block_hash, now, reason, index]
    @db.exec "insert or replace into archived_recipients select ?, ?, ?, * from recipients where block_id = ?", args: [block_hash, now, reason, index]
    @db.exec "insert or repalce into archived_senders select ?, ?, ?, * from senders where block_id = ?", args: [block_hash, now, reason, index]
    @db.exec "END TRANSACTION"
  rescue e : Exception
    warning "Rolling back db due to error when archiving block with message: #{e.message || "unknown"}"
    @db.exec("ROLLBACK")
  end

  def archive_blocks(from : Int64, reason : String) # reason: restore or sync
    now = __timestamp
    @db.exec "BEGIN TRANSACTION"
    blocks = get_blocks_via_query("select * from blocks where idx >= ?", from)
    blocks.each do |block|
      block_hash = block.to_hash
      index = block.index
      @db.exec "insert or replace into archived_blocks select ?, ?, ?, * from blocks where idx = ?", args: [block_hash, now, reason, index]
      @db.exec "insert or replace into archived_transactions select ?, ?, ?, * from transactions where block_id = ?", args: [block_hash, now, reason, index]
      @db.exec "insert or replace into archived_recipients select ?, ?, ?, * from recipients where block_id = ?", args: [block_hash, now, reason, index]
      @db.exec "insert or replace into archived_senders select ?, ?, ?, * from senders where block_id = ?", args: [block_hash, now, reason, index]
    end
    @db.exec "END TRANSACTION"
  rescue e : Exception
    warning "Rolling back db due to error when archiving blocks with message: #{e.message || "unknown"}"
    @db.exec("ROLLBACK")
  end

  def archive_blocks_of_kind(from : Int64, reason : String, kind : BlockKind) # reason: restore or sync
    now = __timestamp
    @db.exec "BEGIN TRANSACTION"
    blocks = get_blocks_via_query("select * from blocks where idx >= ? and kind = ?", from, kind.to_s)
    blocks.each do |block|
      block_hash = block.to_hash
      index = block.index
      @db.exec "insert or replace into archived_blocks select ?, ?, ?, * from blocks where idx = ?", args: [block_hash, now, reason, index]
      @db.exec "insert or replace into archived_transactions select ?, ?, ?, * from transactions where block_id = ?", args: [block_hash, now, reason, index]
      @db.exec "insert or replace into archived_recipients select ?, ?, ?, * from recipients where block_id = ?", args: [block_hash, now, reason, index]
      @db.exec "insert or replace into archived_senders select ?, ?, ?, * from senders where block_id = ?", args: [block_hash, now, reason, index]
    end
    @db.exec "END TRANSACTION"
  rescue e : Exception
    warning "Rolling back db due to error when archiving blocks with message: #{e.message || "unknown"}"
    @db.exec("ROLLBACK")
  end

  # ------- Delete -------
  def delete_block(from : Int64)
    @db.exec "delete from blocks where idx = ?", from
    @db.exec "delete from transactions where block_id = ?", from
    @db.exec "delete from senders where block_id = ?", from
    @db.exec "delete from recipients where block_id = ?", from
  end

  def delete_blocks(from : Int64)
    @db.exec "delete from blocks where idx >= ?", from
    @db.exec "delete from transactions where block_id >= ?", from
    @db.exec "delete from senders where block_id >= ?", from
    @db.exec "delete from recipients where block_id >= ?", from
  end

  def delete_blocks_of_kind(from : Int64, kind : BlockKind)
    blocks = get_block_ids_from(from, kind)
    if blocks.size > 0
      block_ids = blocks.map { |b| "'#{b}'" }.uniq.join(",")
      @db.exec "delete from blocks where idx in (#{block_ids})"
      @db.exec "delete from transactions where block_id in (#{block_ids})"
      @db.exec "delete from senders where block_id in (#{block_ids})"
      @db.exec "delete from recipients where block_id in (#{block_ids})"
    end
  end

  def get_block_ids_from(from : Int64, kind : BlockKind)
    ids = [] of Int64
    @db.query("select idx from blocks where idx >= ? and kind = ?", from, kind.to_s) do |rows|
      rows.each do
        res = rows.read(Int64 | Nil)
        ids << res unless res.nil?
      end
    end
    ids
  end

  def make_validation_hash_from(block_ids : Array(Int64)) : String
    hashes = [] of String
    ids = block_ids.map { |b| "'#{b}'" }.uniq.join(",")
    @db.query("select prev_hash from blocks where idx in (#{ids})") do |rows|
      rows.each do
        res = rows.read(String)
        hashes << res
      end
    end
    concatenated_hashes = hashes.join("")
    sha256(concatenated_hashes)
  end

  # ------- API -------
  def get_paginated_blocks(page, per_page, direction, sort_field) : Blockchain::Chain
    limit = per_page
    offset = Math.max((limit * page) - limit, 0)

    get_blocks_via_query(
      "select * from blocks " \
      "order by #{sort_field} #{direction} " \
      "limit ? offset ?", limit, offset)
  end

  def latest_difficulty
    @db.query_one("select difficulty from blocks order by idx desc limit 1", as: Int32)
  end
end
