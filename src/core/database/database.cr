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

module ::Sushi::Core
  class Database
    getter path : String

    @db : DB::Database

    def initialize(@path : String)
      @db = DB.open("sqlite3://#{File.expand_path(path)}")
      @db.exec "create table if not exists blocks (idx integer primary key, json text)"
    end

    def push_block(block : Block)
      index = block.index
      json = block.to_json

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

    def get_block(index : Int64) : Block?
      block : Block? = nil

      @db.query "select json from blocks where idx = ?", [index] do |rows|
        rows.each do
          json = rows.read(String)
          block = Block.from_json(json)
        end
      end

      block
    end

    def max_index : Int64
      idx : Int64? = nil

      @db.query "select max(idx) from blocks" do |rows|
        rows.each do
          idx = rows.read(Int64|Nil)
        end
      end

      idx || -1_i64
    end
  end
end
