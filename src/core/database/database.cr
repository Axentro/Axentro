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

module ::Sushi::Core
  class Database
    getter path : String

    @db : DB::Database

    def initialize(@path : String)
      @db = DB.open("sqlite3://#{File.expand_path(path)}")
      @db.exec "create table if not exists blocks (idx integer primary key, json text)"
    end

    def push_block(block : SlowBlock | FastBlock)
      debug "database.push_block with block of kind: #{block.kind}"
      index = block.index
      json = block.to_json

      debug "inserting block into database with size: #{json.size}"
      @db.exec "insert into blocks values (?, ?)", [index.to_i64, json]
    end

    def delete_blocks(from : Int64)
      @db.exec "delete from blocks where idx >= ?", [from]
    end

    def replace_chain(chain : Blockchain::Chain)
      delete_blocks(chain[0].index)

      chain.each do |block|
        index = block.index
        json = block.to_json

        @db.exec "insert into blocks values (?, ?)", [index.to_i64, json]
      end
    end

    def get_block(index : Int64) : (SlowBlock? | FastBlock?)
      block : (SlowBlock? | FastBlock?) = nil

      @db.query "select json from blocks where idx = ?", [index] do |rows|
        rows.each do
          json = rows.read(String)
          block = determine_block_kind(json)
        end
      end

      block
    end

    def determine_block_kind(json) : SlowBlock | FastBlock
      if json.includes?("nonce")
        SlowBlock.from_json(json)
      else
        FastBlock.from_json(json)
      end
    end

    def max_index : Int64
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
