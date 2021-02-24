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
# require "../blockchain/*"
# require "../blockchain/block/*"
require "../fast_pool_database/*"
require "../fast_pool_database/migrations/*"
require "../modules/logger"

module ::Axentro::Core
  class FastPool
    MEMORY        = "%3Amemory%3A"
    SHARED_MEMORY = "%3Amemory%3A%3Fcache%3Dshared"
    @db : DB::Database

    def initialize(database_path : String)
      dir = Path[database_path].parent
      path = File.expand_path("#{dir}/fast_pool.sqlite3")
      # @db = DB.open("sqlite3://#{path}")
      @db = DB.open("sqlite3://#{memory_or_disk(path)}")

      # apply migrations
      mg = MG::Migration.new(@db, tag: "fast_pool")
      mg.migrate

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
      # value.starts_with?(MEMORY) ? value : File.expand_path(value)
      if value.starts_with?(MEMORY)
        value
      else
        dir = Path[value].parent.to_s
        FileUtils.mkdir_p(dir) unless File.exists?(dir)
        File.expand_path(value)
      end
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
end
