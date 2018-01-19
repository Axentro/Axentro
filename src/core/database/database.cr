module ::Sushi::Core

  class Database

    @db : DB::Database

    def initialize(path : String)
      @db = DB.open("sqlite3://#{path}")
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

    def replace_chain(chain : Models::Chain)
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
          block = Block.from_json(rows.read(String))
        end
      end

      block
    end
  end
end
