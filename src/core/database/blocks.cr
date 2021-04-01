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
  BLOCK_CHECKPOINT_SIZE = 2000

  # ------- Definition -------
  def block_insert_fields_string : String
    "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
  end

  # ------- Insert -------
  def block_insert_values_array(block : Block) : Array(DB::Any)
    ary = [] of DB::Any
    ary << block.index << block.nonce.to_s << block.prev_hash << block.timestamp << block.difficulty << block.address << block.kind.to_s << block.public_key << block.signature << block.hash << block.version.to_s << block.hash_version.to_s << block.merkle_tree_root << block.checkpoint << block.mining_version.to_s
    ary
  end

  # def push_block(block : Block)
  #   verbose "database.push_block with block index #{block.index} of kind: #{block.kind}"
  #   @db.exec "BEGIN TRANSACTION"
  #   block.transactions.each_with_index do |t, ti|
  #     verbose "writing transaction #{ti} to database with short ID of #{t.short_id}" if ti < 4
  #     t.senders.each_index do |i|
  #       @db.exec "insert into senders values (#{sender_insert_fields_string})", args: sender_insert_values_array(block, t, i)
  #     end
  #     t.recipients.each_index do |i|
  #       @db.exec "insert into recipients values (#{recipient_insert_fields_string})", args: recipient_insert_values_array(block, t, i)
  #     end
  #     t.assets.each_index do |i|
  #       @db.exec "insert into assets values (#{asset_insert_fields_string})", args: asset_insert_values_array(block, t, i)
  #     end
  #     @db.exec "insert into transactions values (#{transaction_insert_fields_string})", args: transaction_insert_values_array(t, ti, block.index)
  #   end
  #   verbose "inserting block with #{block.transactions.size} transactions into database with index: #{block.index}"
  #   @db.exec "insert into blocks values (#{block_insert_fields_string})", args: block_insert_values_array(block)
  #   @db.exec "END TRANSACTION"
  # rescue e : Exception
  #   warning "Rolling back db due to error when pushing block to database with message: #{e.message || "unknown"}"
  #   @db.exec("ROLLBACK")
  # end

  # insert or replace block
  def inplace_block(block : Block)
    verbose "database.push_block with block index #{block.index} of kind: #{block.kind}"
    @db.exec "BEGIN TRANSACTION"
    delete_block(block.index)
    block.transactions.each_with_index do |t, ti|
      verbose "writing transaction #{ti} to database with short ID of #{t.short_id}" if ti < 4
      t.senders.each_index do |i|
        @db.exec "insert into senders values (#{sender_insert_fields_string})", args: sender_insert_values_array(block, t, i)
      end
      t.recipients.each_index do |i|
        @db.exec "insert into recipients values (#{recipient_insert_fields_string})", args: recipient_insert_values_array(block, t, i)
      end
      t.assets.each_index do |i|
        @db.exec "insert into assets values (#{asset_insert_fields_string})", args: asset_insert_values_array(block, t, i)
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
        version = BlockVersion.parse(rows.read(String))
        hash_version = HashVersion.parse(rows.read(String))
        merkle_tree_root = rows.read(String)
        checkpoint = rows.read(String)
        mining_version = MiningVersion.parse(rows.read(String))

        blocks << Block.new(idx, [] of Transaction, nonce, prev_hash, timestamp, diffculty, BlockKind.parse(kind_string), address, public_key, signature, hash, version, hash_version, merkle_tree_root, checkpoint, mining_version)
      end
    end

    blocks.each do |block|
      block.set_transactions(get_all_transactions(block.index))
    end

    blocks
  end

  def self.retrieve_blocks(conn : DB::Connection, from_index : Int64 = 0_i64, kind : BlockKind? = nil)
    kind_condition = kind ? "and kind = '#{kind}'" : ""
    query = "select * from blocks where idx >= ? #{kind_condition}"
    Blocks.retrieve_blocks_for_query(conn, query, from_index) do |block|
      yield block
    end
  end

  def self.retrieve_blocks_for_query(conn : DB::Connection, query : String, *args)
    block : Block? = nil
    conn.query(query, args: args.to_a) do |block_rows|
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
        b_version = BlockVersion.parse(block_rows.read(String))
        b_hash_version = HashVersion.parse(block_rows.read(String))
        b_merkle_tree_root = block_rows.read(String)
        b_checkpoint = block_rows.read(String)
        b_mining_version = MiningVersion.parse(block_rows.read(String))

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
            conn.query("select * from recipients where transaction_id = ? order by idx asc", t_id) do |rec_rows|
              rec_rows.each do
                rec_rows.read(String)
                rec_rows.read(Int64)
                rec_rows.read(Int32)
                address = rec_rows.read(String)
                amount = rec_rows.read(Int64)
                recipients << Recipient.new(address, amount)
              end
            end

            senders = [] of Transaction::Sender
            conn.query("select * from senders where transaction_id = ? order by idx asc", t_id) do |snd_rows|
              snd_rows.each do
                snd_rows.read(String?)
                snd_rows.read(Int64)
                snd_rows.read(Int32)
                address = snd_rows.read(String)
                public_key = snd_rows.read(String)
                amount = snd_rows.read(Int64)
                fee = snd_rows.read(Int64)
                signature = snd_rows.read(String)
                senders << Sender.new(address, public_key, amount, fee, signature)
              end
            end

            assets = [] of Transaction::Asset
            conn.query("select * from assets where transaction_id = ? order by idx asc", t_id) do |asset_rows|
              asset_rows.each do
                asset_id = asset_rows.read(String)
                name = asset_rows.read(String)
                description = asset_rows.read(String)
                media_location = asset_rows.read(String)
                media_hash = asset_rows.read(String)
                quantity = asset_rows.read(Int32)
                terms = asset_rows.read(String)
                version = asset_rows.read(Int32)
                timestamp = asset_rows.read(Int64)
                assets << Asset.new(asset_id, name, description, media_location, media_hash, quantity, terms, version, timestamp)
              end
            end

            t = Transaction.new(t_id, t_action, senders, recipients, assets, t_message, t_token, t_prev_hash, t_timestamp, t_scaled, t_kind, t_version)
            transactions << t
          end

          block_kind = BlockKind.parse(b_kind_string)
          block = Block.new(b_idx, transactions, b_nonce, b_prev_hash, b_timestamp, b_diffculty, block_kind, b_address, b_public_key, b_signature, b_hash, b_version, b_hash_version, b_merkle_tree_root, b_checkpoint, b_mining_version)

          yield block
        end
      end
    end
  end

  def validate_local_db_blocks : ReplaceBlocksResult
    # only care about slow result here because need to resync on failure during receive from peer
    # during startup phase when this is called - just archive and delete invalid blocks and startup
    result = validate_local_db_blocks_for(BlockKind::SLOW)
    validate_local_db_blocks_for(BlockKind::FAST)

    result
  end

  def validate_local_db_blocks_for(kind : BlockKind) : ReplaceBlocksResult
    result = ReplaceBlocksResult.new(0_i64, true)
    max = highest_index_of_kind(kind)
    blocks = [] of Block
    block : Block? = nil
    fast_checkpoint_size = BLOCK_CHECKPOINT_SIZE + 1
    amount_to_take = (BLOCK_CHECKPOINT_SIZE / 2).to_i
    @db.using_connection do |conn|
      prev_block : Block? = nil
      Blocks.retrieve_blocks_for_query(conn, "select * from blocks where kind = ? order by idx asc", kind.to_s) do |_block|
        block = _block
        blocks << block

        if block.index < (kind == BlockKind::SLOW ? BLOCK_CHECKPOINT_SIZE : fast_checkpoint_size)
          # validate without checkpoints
          if prev_block
            validated_block = BlockValidator.quick_validate(block, prev_block)
            raise Axentro::Common::AxentroException.new(validated_block.reason) unless validated_block.valid
            progress("block ##{block.index} was validated", block.index, max)
          end
        else
          # validate using checkpoints
          next if block.checkpoint == ""
          validated_block = BlockValidator.checkpoint_validate(block, blocks.reject(&.index.==(block.index)).last(amount_to_take))
          blocks = [blocks.last]
          raise Axentro::Common::AxentroException.new(validated_block.reason) unless validated_block.valid
          progress("block ##{block.index} was validated", block.index, max)
        end

        prev_block = block
        result.index = block.index
      end
    end
    result
  rescue e : Exception
    result = ReplaceBlocksResult.new(0_i64, false)
    if block
      block_kind = BlockKind.parse(block.kind)
      result.index = block.index
      error "Error validating blocks from database at index: #{block.index}"
      error e.message || "unknown error while validating blocks from database"
      warning "archiving blocks from index #{block.index} and up"
      archive_blocks_of_kind(block.index, "db_validate", block_kind)
      warning "deleting #{block_kind} blocks from index #{block.index} and up"
      delete_blocks_of_kind(block.index, block_kind)
    end
    result
  end

  def stream_blocks_from(index : Int64, kind : BlockKind)
    block : Block? = nil
    total_size = 0
    @db.transaction do |tx|
      conn = tx.connection
      total_size = conn.query_one("select count(*) from blocks where idx >= ? and kind = ?", index, kind.to_s, as: Int32)
      Blocks.retrieve_blocks(conn, index, kind) do |_block|
        block = _block
        yield block, total_size
      end
    end
  rescue e : Exception
    if block
      error "Error fetching blocks from database at index: #{block.index}"
      error e.message || "unknown error"
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

  def get_highest_block : Block?
    blocks = get_blocks_via_query("select * from blocks order by timestamp desc limit 1")
    blocks.size > 0 ? blocks.first : nil
  end

  def get_highest_block! : Block?
    blocks = get_blocks_via_query("select * from blocks order by timestamp desc limit 1")
    blocks.size > 0 ? blocks.first : nil
  end

  def get_highest_block_for_kind(kind : BlockKind) : Block?
    blocks = get_blocks_via_query("select * from blocks where idx in (select max(idx) from blocks where kind = ?)", kind.to_s)
    blocks.size > 0 ? blocks.first : nil
  end

  def get_highest_block_for_kind!(kind : BlockKind) : Block
    blocks = get_blocks_via_query("select * from blocks where idx in (select max(idx) from blocks where kind = ?)", kind.to_s)
    blocks.size > 0 ? blocks.first : raise "get_highest_block_for_kind! did not find a #{kind} block"
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
    index_list = ids.join(&.to_s.+(","))
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
      block_ids = blocks.map { |b| "'#{b}'" }.uniq!.join(",")
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

  # write checkpoint merkle for every 1000th Slow and 1001th Fast
  # on validate if blocks have checkpoints then validate only checkpoints otherwise validate normal quick
  def get_checkpoint_merkle(index : Int64, kind : BlockKind) : String
    result = ""
    @db.using_connection do |conn|
      result = Blocks.get_checkpoint_merkle(conn, index, kind)
    end
    result
  end

  def self.get_checkpoint_merkle(conn : DB::Connection, index : Int64, kind : BlockKind) : String
    # slow block modulo should be 0 and fast block modulo should be 1
    return "" if (index % BLOCK_CHECKPOINT_SIZE) != (kind == BlockKind::SLOW ? 0 : 1)
    blocks = [] of Block
    start_index = index - BLOCK_CHECKPOINT_SIZE
    Blocks.retrieve_blocks_for_query(conn, "select * from blocks where kind = ? and idx between ? and ? order by idx asc", kind.to_s, start_index, index - 2) do |block|
      blocks << block
    end
    MerkleTreeCalculator.new(HashVersion::V2).calculate_merkle_tree_root(blocks)
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

  include Protocol
end
