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
require "../database/*"

module ::Sushi::Core
  class Database
    getter path : String
    MEMORY = "%3Amemory%3A"
    SHARED_MEMORY = "%3Amemory%3A%3Fcache%3Dshared"

    @db : DB::Database

    def initialize(@path : String)
      @db = DB.open("sqlite3://#{memory_or_disk(path)}")
      @db.exec "create table if not exists blocks (#{block_table_create_string})"
      @db.exec "create table if not exists transactions (#{transaction_table_create_string}, primary key (#{transaction_primary_key_string}))"
      @db.exec "create table if not exists recipients (#{recipient_table_create_string}, primary key (#{recipient_primary_key_string}))"
      @db.exec "create table if not exists senders (#{sender_table_create_string}, primary key (#{sender_primary_key_string}))"
      @db.exec "create table if not exists rejects (#{rejects_table_create_string}, primary key (#{rejects_primary_key_string}))"
      @db.exec "PRAGMA synchronous=OFF"
      @db.exec "PRAGMA cache_size=10000"
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

      @db.query "select max(idx) from blocks where kind = '#{kind.to_s}'" do |rows|
        rows.each do
          idx = rows.read(Int64 | Nil)
        end
      end

      idx || -1_i64
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

    def lowest_index_after_time(given_time : Int64, kind : Block::BlockKind)
      idx : Int64? = nil

      the_query = "select min(idx) from blocks where timestamp >= #{given_time} and kind = '#{kind.to_s}'"
      debug "query in lowest_index_after_time: #{the_query}"
      @db.query the_query do |rows|
        rows.each do
          idx = rows.read(Int64 | Nil)
        end
      end

      idx || 0_i64
    end

    include Logger
    include Data::Blocks
    include Data::Rejects
    include Data::Senders
    include Data::Recipients
    include Data::Transactions
  end
end
