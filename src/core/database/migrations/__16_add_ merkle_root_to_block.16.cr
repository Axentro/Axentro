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

@[MG::Tags("main")]
class AddMerkleRootToBlock < MG::Base
  include Axentro::Core
  include Data

  def up : String
    <<-SQL
      ALTER TABLE blocks ADD COLUMN merkle_tree_root TEXT NOT NULL DEFAULT "0"
    SQL
  end

  # def after_up(conn : DB::Connection)
  #   # ms = MigrationSupport.new(conn)

  #   # ms.transactions_by_query("select * from transactions where block_id >= 0").each do |block_id, transactions|
  #   #   merkle = MerkleTreeCalculator.new("V1").calculate_merkle_tree_root(transactions)
  #   #   conn.exec("update blocks set merkle_tree_root = '#{merkle}' where idx = ?", block_id)
  #   # end

  #   # transactions
  #   Blocks.retrieve_blocks(conn) do |block|
  #     sorted_aligned_transactions = block.transactions.select(&.is_coinbase?) + block.transactions.reject(&.is_coinbase?).sort_by(&.timestamp)
  #     sorted_aligned_transactions.map_with_index do |transaction, index|
  #       transaction.add_prev_hash((index == 0 ? "0" : sorted_aligned_transactions[index - 1].to_hash))
  #       if transaction.prev_hash != 0
  #         conn.exec("update transactions set prev_hash = '#{transaction.prev_hash}' where id = ?", transaction.id)
  #       end
  #     end
  #   end

  #   # merkle
  #   Blocks.retrieve_blocks(conn) do |block|
  #     merkle = MerkleTreeCalculator.new("V1").calculate_merkle_tree_root(block.transactions)
  #     conn.exec("update blocks set merkle_tree_root = '#{merkle}' where idx = ?", block.index)
  #   end

  #   [BlockKind::SLOW, BlockKind::FAST].each do |block_kind|
  #     prev_block : Block? = nil
  #     Blocks.retrieve_blocks(conn, 0_i64, block_kind) do |block|

  #       if prev_block.nil?
  #         prev_block = block
  #         next
  #       end

  #       prev_block_hash = prev_block.not_nil!.to_hash
  #       conn.exec("update blocks set prev_hash = '#{prev_block_hash}' where idx = ?", block.index)

  #       prev_block = block
  #     end
  #   end
  # end

  def down : String
    # sqlite3 does not support drop column so have to do this
    <<-SQL
      CREATE TEMPORARY TABLE blocks_temporary (
        idx              INTEGER PRIMARY KEY,
        nonce            TEXT NOT NULL,
        prev_hash        TEXT NOT NULL,
        timestamp        INTEGER NOT NULL,
        difficulty       INTEGER NOT NULL,
        address          TEXT NOT NULL,
        kind             TEXT NOT NULL,
        public_key       TEXT NOT NULL,
        signature        TEXT NOT NULL,
        hash             TEXT NOT NULL,
        version          TEXT NOT NULL,
        hash_version     TEXT NOT NULL,
        merkle_tree_root TEXT NOT NULL,
      );
      INSERT INTO blocks_temporary SELECT * FROM blocks;
    DROP TABLE blocks;
    CREATE TABLE blocks (
        idx             INTEGER PRIMARY KEY,
        nonce           TEXT NOT NULL,
        prev_hash       TEXT NOT NULL,
        timestamp       INTEGER NOT NULL,
        difficulty      INTEGER NOT NULL,
        address         TEXT NOT NULL,
        kind            TEXT NOT NULL,
        public_key      TEXT NOT NULL,
        signature       TEXT NOT NULL,
        hash            TEXT NOT NULL,
        version         TEXT NOT NULL,
        hash_version    TEXT NOT NULL,
      );
      INSERT INTO blocks SELECT idx, nonce, prev_hash, timestamp, difficulty, address, kind, public_key, signature, hash, version, hash_version
    FROM blocks_temporary;
    DROP TABLE blocks_temporary;
    SQL
  end
end
