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
require "../blockchain/*"
require "../blockchain/block/*"

module ::Sushi::Core
  class Database
    getter path : String

    @db : DB::Database

    def initialize(@path : String)
      @db = DB.open("sqlite3://#{File.expand_path(path)}")
      @db.exec "create table if not exists blocks (#{block_table_create_string})"
      @db.exec "create table if not exists transactions (#{transaction_table_create_string}, primary key (#{transaction_primary_key_string}))"
      @db.exec "create table if not exists recipients (#{recipient_table_create_string}, primary key (#{recipient_primary_key_string}))"
      @db.exec "create table if not exists senders (#{sender_table_create_string}, primary key (#{sender_primary_key_string}))"
      @db.exec "PRAGMA synchonous = OFF"
      @db.exec "PRAGMA cache_size=10000"
    end

    def block_table_create_string : String
      "idx integer primary key, nonce text, prev_hash text, timestamp integer, difficulty integer, address text, kind text, public_key text, sign_r text, sign_s text, hash text"
    end

    def block_insert_fields_string : String
     "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
    end

    def block_insert_values_array(block : SlowBlock | FastBlock) : Array(DB::Any)
      ary = [] of DB::Any
      case block
        when SlowBlock
          ary << block.index << block.nonce.to_s << block.prev_hash << block.timestamp << block.difficulty << block.address << block.kind.to_s << "" << "" << "" << ""
        when FastBlock
          ary << block.index << "" << block.prev_hash << block.timestamp << 0 << block.address << block.kind.to_s << block.public_key << block.sign_r << block.sign_s << block.hash
      end
      ary
    end

    def transaction_table_create_string
      "id text, idx integer, block_id integer, action text, message text, token text, prev_hash text, timestamp integer, scaled integer, kind text"
    end

    def transaction_primary_key_string
      "id, idx, block_id"
    end

    def transaction_insert_fields_string
      "?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
    end

    def transaction_insert_values_array(t : Transaction, transaction_idx : Int32, block_index : Int64) : Array(DB::Any)
      ary = [] of DB::Any
      ary << t.id << transaction_idx << block_index << t.action << t.message << t.token << t.prev_hash << t.timestamp << t.scaled << t.kind.to_s
    end

    def sender_table_create_string
      "transaction_id text, block_id integer, idx integer, address text, public_key text, amount integer, fee integer, sign_r text, sign_s text"
    end

    def sender_primary_key_string
      "transaction_id, block_id, idx"
    end

    def sender_insert_fields_string
      "?, ?, ?, ?, ?, ?, ?, ?, ?"
    end

    def sender_insert_values_array(b : Block, t : Transaction, sender_index : Int32) : Array(DB::Any)
      ary = [] of DB::Any
      s = t.senders[sender_index]
      ary << t.id << b.index << sender_index << s[:address] << s[:public_key] << s[:amount] << s[:fee] << s[:sign_r] << s[:sign_s]
    end

    def recipient_table_create_string
      "transaction_id text, block_id integer, idx integer, address text, amount integer"
    end

    def recipient_primary_key_string
      "transaction_id, block_id, idx"
    end

    def recipient_insert_fields_string
      "?, ?, ?, ?, ?"
    end

    def recipient_insert_values_array(b : Block, t : Transaction, recipient_index : Int32) : Array(DB::Any)
      ary = [] of DB::Any
      r = t.recipients[recipient_index]
      ary << t.id << b.index << recipient_index << r[:address] << r[:amount]
    end

    def push_block(block : SlowBlock | FastBlock)
      #debug "database.push_block with block index #{block.index} of kind: #{block.kind}"
      @db.exec "BEGIN TRANSACTION"
      block.transactions.each_index do |ti|
        t = block.transactions[ti]
        #debug "writing transaction #{ti} to database with short ID of #{t.short_id}" if ti < 4
        t.senders.each_index do |i|
         @db.exec "insert into senders values (#{sender_insert_fields_string})", args: sender_insert_values_array(block, t, i)
        end
        t.recipients.each_index do |i|
         @db.exec "insert into recipients values (#{recipient_insert_fields_string})", args: recipient_insert_values_array(block, t, i)
        end
       @db.exec "insert into transactions values (#{transaction_insert_fields_string})", args: transaction_insert_values_array(t, ti, block.index)
      end
      #debug "inserting block with #{block.transactions.size} transactions into database with index: #{block.index}"
      @db.exec "insert into blocks values (#{block_insert_fields_string})", args: block_insert_values_array(block)
      @db.exec "END TRANSACTION"
    end

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

    def replace_block(block : SlowBlock | FastBlock)
      delete_block(block.index)
      push_block(block)
    end

    def replace_chain(chain : Blockchain::Chain)
      delete_blocks(chain[0].index)

      chain.each do |block|
        push_block(block)
      end
    end

    def get_senders(t : Transaction) : Transaction::Senders
      senders = [] of Transaction::Sender
      @db.query "select * from senders where transaction_id = ? order by idx", t.id do |rows|
        rows.each do
          rows.read(String?)
          rows.read(Int64)
          rows.read(Int32)
          senders << {address: rows.read(String), public_key: rows.read(String), amount: rows.read(Int64), fee: rows.read(Int64),
                      sign_r: rows.read(String), sign_s: rows.read(String) }
        end
      end
      senders
    end

    def get_recipients(t : Transaction) : Transaction::Recipients
      recipients = [] of Transaction::Recipient
      @db.query "select * from recipients where transaction_id = ? order by idx", t.id do |rows|
        rows.each do
          rows.read(String)
          rows.read(Int64)
          rows.read(Int32)
          recipients << {address: rows.read(String), amount: rows.read(Int64) }
        end
      end
      recipients
    end

    def get_transactions(index : Int64)
      transactions = [] of Transaction
      #debug "Reading transactions from the database for block #{index}"
      ti = 0
      @db.query "select * from transactions where block_id = ? order by idx asc", index do |rows|
        rows.each do
          t_id = rows.read(String)
          rows.read(Int32)
          rows.read(Int64)
          action = rows.read(String)
          message = rows.read(String)
          token = rows.read(String)
          prev_hash = rows.read(String)
          timestamp = rows.read(Int64)
          scaled = rows.read(Int32)
          kind_string = rows.read(String)
          kind = kind_string == "SLOW" ? TransactionKind::SLOW : TransactionKind::FAST

          t = Transaction.new(t_id, action, [] of Transaction::Sender, [] of Transaction::Recipient, message, token, prev_hash, timestamp, scaled, kind)
          transactions << t
          #debug "reading transaction #{ti} from database with short ID of #{t.short_id}" if ti < 4
          ti += 1
        end
      end
      transactions.each do |t|
        t.set_senders(get_senders(t))
        t.set_recipients(get_recipients(t))
      end
      transactions
    end

    def get_blocks_via_query(the_query : String) : Blockchain::Chain
      blocks : Blockchain::Chain = [] of SlowBlock | FastBlock
      @db.query the_query do |rows|
        rows.each do
          idx = rows.read(Int64)
          nonce_string = rows.read(String)
          nonce = nonce_string.size > 0 ? nonce_string.to_u64 : 0_u64
          prev_hash = rows.read(String)
          timestamp = rows.read(Int64)
          diffculty = rows.read(Int32)
          address = rows.read(String)
          kind_string = rows.read(String)
          public_key = rows.read(String)
          sign_r = rows.read(String)
          sign_s = rows.read(String)
          hash = rows.read(String)
          #debug "read block idx: #{idx}"
          #debug "read nonce string: #{nonce_string}"
          #debug "read nonce: #{nonce}"
          #debug "read prev_hash: #{prev_hash}"
          #debug "read timestamp: #{timestamp}"
          #debug "read address: #{address}"
          #debug "read block kind: #{kind_string}"
          if kind_string == "SLOW"
            #debug "read diffculty: #{diffculty}"
            blocks << SlowBlock.new(idx, [] of Transaction, nonce, prev_hash, timestamp, diffculty, address)
          else
            #debug "read public_key: #{public_key}"
            #debug "read sign_r: #{sign_r}"
            #debug "read sign_s: #{sign_s}"
            #debug "read hash: #{hash}"
            blocks << FastBlock.new(idx, [] of Transaction, prev_hash, timestamp, address, public_key, sign_r, sign_s, hash)
          end
        end
      end

      blocks.each do |block|
        case block
          when SlowBlock
            block.set_transactions(get_transactions(block.index))
          when FastBlock
            block.set_transactions(get_transactions(block.index))
        end
      end

      blocks
    end

    def get_block(index : Int64) : Block?
      #debug "Reading block from the database for block #{index}"
      block : Block? = nil
      blocks = get_blocks_via_query("select * from blocks where idx = #{index}")
      block = blocks[0] if blocks.size > 0
      block
    end

    def get_blocks(index : Int64) : Blockchain::Chain
      #debug "Reading blocks from the database starting at block #{index}"
      blocks = get_blocks_via_query("select * from blocks where idx >= #{index}")
      blocks
    end

    def get_blocks_not_in_list(the_list : Array(Int64))
      #debug "get_blocks_not_in_list called, list length: #{the_list.size}"
      the_index_list = ""
      the_list.each_index do |i|
        the_index_list += the_list[i].to_s
        the_index_list += ", " if i < the_list.size - 1
      end
      blocks = get_blocks_via_query("select * from blocks where idx not in (#{the_index_list})")
      blocks
    end

    def total_blocks : Int32
      @db.query_one("select count(*) from blocks", as: Int32)
    end

    def highest_index : Int64
      idx : Int64? = nil

      @db.query "select max(idx) from blocks" do |rows|
        rows.each do
          idx = rows.read(Int64 | Nil)
        end
      end

      idx || -1_i64
    end

    include Logger
  end
end
