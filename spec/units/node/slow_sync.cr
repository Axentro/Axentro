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

require "./../../spec_helper"

include Axentro::Core
include Units::Utils
include Axentro::Core::NodeComponents
include Axentro::Core::Keys

describe SlowSync do
  describe "CREATE" do
    # incoming block is not in local db and is next in sequence
    it "should create incoming block in local db and broadcast onwards" do
      with_factory do |block_factory, _|
        blockchain = block_factory.blockchain
        database = blockchain.database

        block_factory.add_slow_block
        mining_block = blockchain.mining_block

        latest_slow = get_latest_slow(database)
        incoming_block = make_incoming_next_in_sequence(latest_slow, blockchain)

        has_block = database.get_block(incoming_block.index)

        slow_sync = SlowSync.new(incoming_block, mining_block, (has_block.nil? ? nil : has_block.not_nil!.as(Block)), latest_slow)
        slow_sync.process.should eq(SlowSyncState::CREATE)
      end
    end
  end
end

private def create_coinbase_transaction(blockchain, index, transactions) : Transaction
  coinbase_amount = blockchain.coinbase_slow_amount(index, transactions)
  blockchain.calculate_coinbase_slow_transaction(coinbase_amount, index, transactions)
end

private def get_latest_slow(database : Database) : Block
  database.get_highest_block_for_kind!(BlockKind::SLOW)
end

private def make_incoming_next_in_sequence(latest_slow : Block, blockchain) : Block
  index = latest_slow.index + 2
  transactions = [create_coinbase_transaction(blockchain, index, [] of Transaction)]
  hash = latest_slow.to_hash
  timestamp = __timestamp
  difficulty = 0
  address = latest_slow.address
  make_incoming_block(index, transactions, hash, timestamp, difficulty, address)
end

private def make_incoming_block(index, transactions, hash, timestamp, difficulty, address)
  Block.new(
    index,
    transactions,
    "0",
    hash,
    timestamp,
    difficulty,
    address,
    BlockVersion::V2,
    HashVersion::V2,
    "",
    MiningVersion::V1
  )
end

# private def add_valid_slow_block(with_refresh : Bool)
#   enable_difficulty("0")
#   @blockchain.refresh_mining_block(0) if with_refresh
#   block = @blockchain.mining_block
#   block.nonce = "11719215035155661212"
#   block.difficulty = 0 # difficulty will be set to 0 for most unit tests
#   # skip validating transactions here so that we can add blocks and still test the transactions in the specs
#   # valid block is tested separately
#   valid_block = @blockchain.valid_block?(block, true)
#   case valid_block
#   when Block
#     @blockchain.push_slow_block(valid_block)
#   else
#     raise "error could not push slow block onto blockchain - block was not valid"
#   end
# end
