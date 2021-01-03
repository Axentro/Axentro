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
require "../database/*"

module ::Axentro::Core
  class FastPool
    @db : DB::Database

    def initialize(database_path : String)
      dir = Path[database_path].parent
      path = File.expand_path("#{dir}/fast_pool.sqlite3")
      @db = DB.open("sqlite3://#{path}")
      @db.exec "create table if not exists transactions (id text primary key,content text not null)"
      @db.exec "PRAGMA synchronous=OFF"
      @db.exec "PRAGMA cache_size=10000"
      @db.exec "PRAGMA journal_mode=WAL"
    end

    # ------- Insert -------
    def insert_transaction(transaction : Transaction)
      @db.exec("insert into transactions (id, content) values (?, ?)", transaction.id, transaction.to_json)
    rescue e : Exception
      warning "Handling error on insert fast transaction to database with message: #{e.message || "unknown"}"
    end

    # ------- Query -------
    def get_all_transactions : Array(Transaction)
      transactions = [] of Transaction
      @db.query(
        "select content from transactions"
      ) do |rows|
        rows.each do
          json = rows.read(String)
          transactions << Transaction.from_json(json)
        end
        transactions
      end
    end

    # ------- Delete -------
    def delete_all
      @db.exec("delete from transactions")
    end

    def delete(transaction : Transaction)
      @db.exec("delete from transactions where id = ?", transaction.id)
    end

    include Logger
  end

  class Database
    getter path : String
    MEMORY        = "%3Amemory%3A"
    SHARED_MEMORY = "%3Amemory%3A%3Fcache%3Dshared"

    @db : DB::Database

    def initialize(@path : String)
      @db = DB.open("sqlite3://#{memory_or_disk(path)}")
      @db.exec "create table if not exists blocks (#{block_table_create_string})"
      @db.exec "create table if not exists transactions (#{transaction_table_create_string}, primary key (#{transaction_primary_key_string}))"
      @db.exec "create table if not exists recipients (#{recipient_table_create_string}, primary key (#{recipient_primary_key_string}))"
      @db.exec "create table if not exists senders (#{sender_table_create_string}, primary key (#{sender_primary_key_string}))"
      @db.exec "create table if not exists rejects (#{rejects_table_create_string}, primary key (#{rejects_primary_key_string}))"
      @db.exec "create table if not exists nonces (#{nonces_table_create_string}, primary key (#{nonces_primary_key_string}))"
      @db.exec "PRAGMA synchronous=OFF"
      @db.exec "PRAGMA cache_size=10000"
      @db.exec "PRAGMA journal_mode=WAL"
    end

    def self.in_memory
      self.new(MEMORY)
    end

    def self.in_shared_memory
      self.new(SHARED_MEMORY)
    end

    private def memory_or_disk(value : String) : String
      value.starts_with?(MEMORY) ? value : File.expand_path(value)
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

    def highest_index_of_kind(kind : Block::BlockKind) : Int64
      idx : Int64? = nil

      @db.query "select max(idx) from blocks where kind = '#{kind}'" do |rows|
        rows.each do
          idx = rows.read(Int64 | Nil)
        end
      end

      idx || 0_i64
    end

    # def highest_fast_index_or_nil : Int64?
    #   @db.query_one("select max(idx) from blocks where kind = ?", Block::BlockKind::FAST.to_s, as: Int64?)
    # end

    # def highest_index : Int64
    #   idx : Int64? = nil

    #   @db.query "select max(idx) from blocks" do |rows|
    #     rows.each do
    #       idx = rows.read(Int64 | Nil)
    #     end
    #   end

    #   idx || -1_i64
    # end

    # def lowest_index_after_time(given_time : Int64, kind : Block::BlockKind)
    #   idx : Int64? = nil

    #   the_query = "select min(idx) from blocks where timestamp >= #{given_time} and kind = '#{kind}'"
    #   debug "query in lowest_index_after_time: #{the_query}"
    #   @db.query the_query do |rows|
    #     rows.each do
    #       idx = rows.read(Int64 | Nil)
    #     end
    #   end

    #   idx || 0_i64
    # end

    # this could return null if there are no fast blocks found after the slow block timestamp
    # this could also return null if the slowblock is not found
    def lowest_fast_index_after_slow_block(index : Int64) : Int64?
      @db.query_one("select min(idx) from blocks where kind = 'FAST' and timestamp >= (select timestamp from blocks where idx = ?)", index, as: Int64?)
    end

    # this could return null if the slowblock is not found
    # this could return null if the index given was 0
    def lowest_slow_index_after_slow_block(index : Int64) : Int64?
      @db.query_one("select max(idx) from blocks where kind = 'SLOW' and timestamp < (select timestamp from blocks where idx = ?)", index, as: Int64?)
    end

    def total(kind : Block::BlockKind)
      idx : Int64? = nil
      @db.query("select count(*) from blocks where kind = ?", kind.to_s) do |rows|
        rows.each do
          idx = rows.read(Int64 | Nil)
        end
      end
      idx || 0_i64
    end

    def search_domain(term : String) : Bool
      @db.query_one("select count(*) from transactions where message = ? limit 1", term, as: Int32) > 0
    end

    def search_address(term : String) : Bool
      @db.query_one("select count(*) from recipients where address = ? limit 1", term, as: Int32) > 0
    end

    def search_transaction(term : String) : Bool
      @db.query_one("select count(*) from transactions where id like ? || '%' limit 1", term, as: Int32) > 0
    end

    def search_block(term : String) : Bool
      @db.query_one("select count(*) from blocks where idx = ? limit 1", term, as: Int32) > 0
    end

    include Logger
    include Data::Nonces
    include Data::Blocks
    include Data::Rejects
    include Data::Senders
    include Data::Recipients
    include Data::Transactions
  end
end
