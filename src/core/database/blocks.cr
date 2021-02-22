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
require "../blockchain/block/*"

module ::Axentro::Core::Data::Blocks
  # ------- Definition -------
  def block_table_create_string : String
    "idx integer primary key, nonce text, prev_hash text, timestamp integer, difficulty integer, address text, kind text, public_key text, signature text, hash text"
  end

  def block_insert_fields_string : String
    "?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
  end

  def archived_block_table_create_string : String
    "block_hash string, archive_timestamp integer, reason text, idx integer, nonce text, prev_hash text, timestamp integer, difficulty integer, address text, kind text, public_key text, signature text, hash text"
  end

  # ------- Insert -------
  def block_insert_values_array(block : SlowBlock | FastBlock) : Array(DB::Any)
    ary = [] of DB::Any
    case block
    when SlowBlock
      ary << block.index << block.nonce.to_s << block.prev_hash << block.timestamp << block.difficulty << block.address << block.kind.to_s << "" << "" << ""
    when FastBlock
      ary << block.index << "" << block.prev_hash << block.timestamp << 0 << block.address << block.kind.to_s << block.public_key << block.signature << block.hash
    end
    ary
  end

  def push_block(block : SlowBlock | FastBlock)
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
    blocks : Blockchain::Chain = [] of SlowBlock | FastBlock
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
        verbose "read block idx: #{idx}"
        verbose "read nonce: #{nonce}"
        verbose "read prev_hash: #{prev_hash}"
        verbose "read timestamp: #{timestamp}"
        verbose "read address: #{address}"
        verbose "read block kind: #{kind_string}"
        if kind_string == "SLOW"
          verbose "read diffculty: #{diffculty}"
          blocks << SlowBlock.new(idx, [] of Transaction, nonce, prev_hash, timestamp, diffculty, address)
        else
          verbose "read public_key: #{public_key}"
          verbose "read signature: #{signature}"
          verbose "read hash: #{hash}"
          blocks << FastBlock.new(idx, [] of Transaction, prev_hash, timestamp, address, public_key, signature, hash)
        end
      end
    end

    blocks.each do |block|
      case block
      when SlowBlock
        block.set_transactions(get_all_transactions(block.index))
      when FastBlock
        block.set_transactions(get_all_transactions(block.index))
      end
    end

    blocks
  end

  def get_block(index : Int64) : Block?
    verbose "Reading block from the database for block #{index}"
    block : Block? = nil
    blocks = get_blocks_via_query("select * from blocks where idx = ?", index)
    block = blocks[0] if blocks.size > 0
    block
  end

  def get_previous_slow_from(index : Int64) : SlowBlock?
    block : SlowBlock? = nil
    blocks = get_blocks_via_query("select * from blocks where idx <= ? and kind = 'SLOW' order by idx desc limit 1", index)
    block = blocks[0].as(SlowBlock) if blocks.size > 0
    block
  end

  def get_highest_block_for_kind(kind : Block::BlockKind)
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

  def get_blocks(index : Int64) : Blockchain::Chain
    verbose "Reading blocks from the database starting at block #{index}"
    get_blocks_via_query("select * from blocks where idx >= ?", index)
  end

  def get_slow_blocks(index : Int64, count : Int32) : Blockchain::Chain
    verbose "Reading blocks from the database starting at block #{index} with count #{count}"
    if index == 0
      get_blocks_via_query("select * from blocks where idx >= ? and kind = 'SLOW' limit ?", index, count)
    else
      get_blocks_via_query("select * from blocks where idx > ? and kind = 'SLOW' limit ?", index, count)
    end
  end

  def batch_by_time(start : Int32, finish : Int32) : Blockchain::Chain
    get_blocks_via_query("select * from blocks where idx between ? and ? order by timestamp asc", start, finish)
  end

  def get_blocks_by_ids(ids : Array(Int64)) : Blockchain::Chain
    index_list = ids.map(&.to_s).join(",")
    get_blocks_via_query("select * from blocks where idx in (#{index_list})")
  end

  def get_fast_blocks(index : Int64, count : Int32) : Blockchain::Chain
    verbose "Reading blocks from the database starting at block #{index} for count #{count}"
    blocks = get_blocks_via_query("select * from blocks where idx > ? and kind = 'FAST' limit ?", index, count)
    blocks
  end

  def get_blocks_not_in_list(the_list : Array(Int64))
    verbose "get_blocks_not_in_list called, list length: #{the_list.size}"
    index_list = the_list.map(&.to_s).join(",")
    get_blocks_via_query("select * from blocks where idx not in (#{index_list})")
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

  def archive_blocks_of_kind(from : Int64, reason : String, kind : Block::BlockKind) # reason: restore or sync
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

  def delete_blocks_of_kind(from : Int64, kind : Block::BlockKind)
    blocks = get_block_ids_from(from, kind)
    if blocks.size > 0
      block_ids = blocks.map { |b| "'#{b}'" }.uniq.join(",")
      @db.exec "delete from blocks where idx in (#{block_ids})"
      @db.exec "delete from transactions where block_id in (#{block_ids})"
      @db.exec "delete from senders where block_id in (#{block_ids})"
      @db.exec "delete from recipients where block_id in (#{block_ids})"
    end
  end

  def get_block_ids_from(from : Int64, kind : Block::BlockKind)
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
