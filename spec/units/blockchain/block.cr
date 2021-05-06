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
include Hashes
include Units::Utils

NODE_ADDRESS = "VDA2NjU5N2JlNDA3ZDk5Nzg4MGY2NjY5YjhhOTUwZTE2M2VmNjM5OWM2M2EyMWQz"

describe Block do
  it "should create a genesis block (new block with no transactions)" do
    block = Block.new(0_i64, [] of Transaction, "0", "genesis", 0_i64, 3_i32, NODE_ADDRESS, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)
    block.index.should eq(0)
    block.transactions.should eq([] of Transaction)
    block.nonce.should eq("0")
    block.prev_hash.should eq("genesis")
    block.merkle_tree_root.should eq("")
  end

  it "should return the header for #to_header" do
    block = Block.new(0_i64, [] of Transaction, "0", "genesis", 0_i64, 3_i32, NODE_ADDRESS, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)
    block.to_header.should eq({index: 0_i64, nonce: "0", prev_hash: "genesis", merkle_tree_root: "", timestamp: 0_i64, difficulty: 3})
  end

  describe "#calculate_merkle_tree_root" do
    it "should return empty merkle tree root value when no transactions" do
      block = Block.new(0_i64, [] of Transaction, a_nonce, "prev_hash", 0_i64, 3_i32, NODE_ADDRESS, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)
      block.calculate_merkle_tree_root(block.transactions).should eq("")
    end

    it "should calculate merkle tree root when coinbase transaction" do
      coinbase_transaction = a_fixed_coinbase_transaction
      block = Block.new(2_i64, [coinbase_transaction], "1", "prev_hash", 0_i64, 3_i32, NODE_ADDRESS, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)
      block.calculate_merkle_tree_root(block.transactions).should eq("07d7374966f804ef9954bf104fb08306b18e4d57")
    end

    it "should calculate merkle tree root when 2 transactions (first is coinbase)" do
      coinbase_transaction = a_fixed_coinbase_transaction
      transaction1 = a_fixed_signed_transaction
      block = Block.new(2_i64, [coinbase_transaction, transaction1], "1", "prev_hash", 0_i64, 3_i32, NODE_ADDRESS, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)
      block.calculate_merkle_tree_root(block.transactions).should eq("70f33958518d589d76bf644aba07351a52424228")
    end
  end

  describe "#valid_block_nonce?" do
    it "should return true when valid" do
      with_factory do |block_factory|
        ENV.delete("AX_SET_DIFFICULTY")
        block = block_factory.add_slow_block.chain.first.as(Block)
        block.nonce = a_nonce
        block.valid_block_nonce?(0).should eq(true)
      end
    end

    it "should less that 3 when invalid" do
      with_factory do |block_factory|
        ENV.delete("AX_SET_DIFFICULTY")
        block = block_factory.add_slow_block.chain.first.as(Block)
        block.nonce = a_nonce
        block.valid_block_nonce?(50).should eq(false)
      end
    end
  end

  describe "#valid?" do
    it "should return true when valid" do
      with_factory do |block_factory|
        chain = block_factory.add_slow_blocks(1).chain
        prev_hash = chain[1].to_hash
        timestamp = chain[1].timestamp
        block = Block.new(4_i64, [a_coinbase_transaction(1199998747_i64)], a_nonce, prev_hash, timestamp, 0_i32, NODE_ADDRESS, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)
        block.valid?(block_factory.blockchain, false).should be_true
      end
    end

    it "should raise invalid mismatch if there is an index mismatch with the prev block" do
      with_factory do |block_factory|
        chain = block_factory.add_slow_blocks(1).chain
        prev_hash = chain[1].to_hash
        timestamp = chain[1].timestamp
        block = Block.new(98_i64, [a_coinbase_transaction(1199969322_i64)], a_nonce, prev_hash, timestamp, 1_i32, NODE_ADDRESS, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)

        expect_raises(Exception, "Index Mismatch: the current block index: 98 should match the latest slow block index: 4") do
          block.valid?(block_factory.blockchain, false)
        end
      end
    end

    it "should raise error if prev hash is invalid" do
      with_factory do |block_factory|
        chain = block_factory.add_slow_blocks(1).chain
        prev_hash = "invalid"
        timestamp = chain[1].timestamp
        block = Block.new(4_i64, [a_coinbase_transaction(1199998747_i64)], a_nonce, prev_hash, timestamp, 0_i32, NODE_ADDRESS, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)

        expect_raises(Exception, /prev_hash is invalid:/) do
          block.valid?(block_factory.blockchain, false)
        end
      end
    end

    it "should raise error if timestamp is invalid because is smaller than prev timestamp" do
      with_factory do |block_factory|
        chain = block_factory.add_slow_blocks(1).chain
        prev_hash = chain[1].to_hash
        timestamp = chain[1].timestamp - 10000000
        block = Block.new(4_i64, [a_coinbase_transaction(1199998747_i64)], a_nonce, prev_hash, timestamp, 0_i32, NODE_ADDRESS, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)

        expect_raises(Exception, /Invalid Timestamp:/) do
          block.valid?(block_factory.blockchain, false)
        end
      end
    end

    it "should raise error if timestamp is invalid because is bigger than next timestamp" do
      with_factory do |block_factory|
        chain = block_factory.add_slow_blocks(1).chain
        prev_hash = chain[1].to_hash
        timestamp = chain[1].timestamp + 10000000
        block = Block.new(4_i64, [a_coinbase_transaction(1199998747_i64)], a_nonce, prev_hash, timestamp, 0_i32, NODE_ADDRESS, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)

        expect_raises(Exception, /Invalid Timestamp:/) do
          block.valid?(block_factory.blockchain, false)
        end
      end
    end

    it "should raise error if merkle tree root is invalid" do
      with_factory do |block_factory|
        chain = block_factory.add_slow_blocks(1).chain
        prev_hash = chain[1].to_hash
        timestamp = chain[1].timestamp
        block = Block.new(4_i64, [a_coinbase_transaction(1199998747_i64)], a_nonce, prev_hash, timestamp, 0_i32, NODE_ADDRESS, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)
        block.merkle_tree_root = "invalid"
        expect_raises(Exception, "Invalid Merkle Tree Root: (expected invalid but got 3a33cd8252ece5f4ad348022ee5c93b71f97a87e)") do
          block.valid?(block_factory.blockchain, false)
        end
      end
    end

    it "should invalidate an incoming block that is of the wrong network type for the chain" do
      with_factory do |block_factory|
        chain = block_factory.add_slow_blocks(1).chain
        prev_hash = chain[1].to_hash
        timestamp = chain[1].timestamp

        mainnet_address = "TTBjYTcxZmNhNjAxZTJkNTAyNGI4MGExMWYzODA1MjdjZjlkNjI3NDEzMDc3NGFj"
        block = Block.new(4_i64, [a_coinbase_transaction(1199998747_i64)], a_nonce, prev_hash, timestamp, 0_i32, mainnet_address, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)

        expect_raises(Exception, "Invalid block network type: incoming block is of type: mainnet but chain is of type: testnet") do
          block.valid?(block_factory.blockchain, false)
        end
      end
    end

    it "should accept an incoming block that is of the correct network type for the chain" do
      with_factory do |block_factory|
        chain = block_factory.add_slow_blocks(1).chain
        prev_hash = chain[1].to_hash
        timestamp = chain[1].timestamp

        testnet_address = "VDAxMWQ4YjY1MTlhNTI2ZDNlMDYxMjk3OTdmYjY5YmRjODcwNzViYjA1YjFjNjBl"
        block = Block.new(4_i64, [a_coinbase_transaction(1199998747_i64)], a_nonce, prev_hash, timestamp, 0_i32, testnet_address, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)

        block.valid?(block_factory.blockchain, false).should be_true
      end
    end

    it "should skip network type check and accept incoming block when chain has no blocks yet" do
      with_factory do |block_factory|
        blockchain = block_factory.blockchain
        mainnet_address = "TTBjYTcxZmNhNjAxZTJkNTAyNGI4MGExMWYzODA1MjdjZjlkNjI3NDEzMDc3NGFj"
        block = blockchain.mining_block
        block.address = mainnet_address
        block.nonce = "11719215035155661212"
        block.difficulty = 0

        chain = blockchain.chain
        prev_hash = chain[0].to_hash
        timestamp = chain[0].timestamp

        block = Block.new(2_i64, [a_coinbase_transaction(1199999373_i64)], a_nonce, prev_hash, timestamp, 0_i32, mainnet_address, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)

        block.valid?(block_factory.blockchain, false).should be_true
      end
    end

    # Fast blocks
    it "should invalidate an incoming fast block that is of the wrong network type for the chain" do
      with_factory do |block_factory|
        block_factory.add_slow_blocks(1).add_fast_block

        mainnet_address = "TTBjYTcxZmNhNjAxZTJkNTAyNGI4MGExMWYzODA1MjdjZjlkNjI3NDEzMDc3NGFj"

        blockchain = block_factory.blockchain
        valid_transactions = blockchain.valid_transactions_for_fast_block
        block = blockchain.mint_fast_block(valid_transactions)
        block.address = mainnet_address

        expect_raises(Exception, "Invalid block network type: incoming block is of type: mainnet but chain is of type: testnet") do
          block.valid?(block_factory.blockchain, false)
        end
      end
    end

    it "should accept an incoming fast block that is of the correct network type for the chain" do
      with_factory do |block_factory|
        block_factory.add_slow_blocks(1).add_fast_block

        testnet_address = "VDAxMWQ4YjY1MTlhNTI2ZDNlMDYxMjk3OTdmYjY5YmRjODcwNzViYjA1YjFjNjBl"

        blockchain = block_factory.blockchain
        valid_transactions = blockchain.valid_transactions_for_fast_block
        block = blockchain.mint_fast_block(valid_transactions)
        block.address = testnet_address

        block.valid?(block_factory.blockchain, false).should be_true
      end
    end
  end

  describe "#valid_as_genesis?" do
    it "should return true when valid" do
      with_factory do |block_factory|
        chain = block_factory.blockchain.chain
        block = chain.first
        block.valid?(block_factory.blockchain, false).should be_true
      end
    end

    it "should raise error if nonce is not 0" do
      with_factory do |block_factory|
        chain = block_factory.blockchain.chain
        block = chain.first.as(Block)
        block.nonce = "1"
        expect_raises(Exception, "nonce has to be '0' for genesis block: 1") do
          block.valid?(block_factory.blockchain, false)
        end
      end
    end

    it "should raise error if prev hash is not 'genesis'" do
      with_factory do |block_factory|
        chain = block_factory.blockchain.chain
        block = chain.first.as(Block)
        block.prev_hash = "invalid"
        expect_raises(Exception, "prev_hash has to be 'genesis' for genesis block: invalid") do
          block.valid?(block_factory.blockchain, false)
        end
      end
    end
  end

  describe "#find_transaction" do
    it "should find a transaction when an matching one exists" do
      coinbase_transaction = a_fixed_coinbase_transaction
      block = Block.new(2_i64, [coinbase_transaction, a_fixed_signed_transaction], a_nonce, "prev_hash_1", 0_i64, 3_i32, NODE_ADDRESS, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)
      block.find_transaction(coinbase_transaction.id).should eq(coinbase_transaction)
    end

    it "should find a transaction when an matching one exists given a partial transaction id" do
      coinbase_transaction = a_fixed_coinbase_transaction
      block = Block.new(2_i64, [coinbase_transaction, a_fixed_signed_transaction], a_nonce, "prev_hash_1", 0_i64, 3_i32, NODE_ADDRESS, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)
      block.find_transaction(coinbase_transaction.id[0, 8]).should eq(coinbase_transaction)
    end

    it "should return nil when cannot find a matching transaction" do
      coinbase_transaction = a_fixed_coinbase_transaction
      block = Block.new(2_i64, [coinbase_transaction, a_fixed_signed_transaction], a_nonce, "prev_hash_1", 0_i64, 3_i32, NODE_ADDRESS, BlockVersion::V2, HashVersion::V2, "", MiningVersion::V1)
      block.find_transaction("transaction-not-found").should be_nil
    end
  end
end

def a_nonce
  "5995816054692193019"
end

def a_fixed_coinbase_transaction
  recipient1 = a_recipient_with_address("VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0", 599999373_i64)
  recipient2 = a_recipient_with_address("VDBhYTYxYzk5MTQ4M2QyZmU1YTA4NzUxZjYzYWUzYzA4ZTExYTgzMjdkNWViODU2", 299999686_i64)
  recipient3 = a_recipient_with_address("VDAyNTk0YjdlMTc4N2FkODRmYTU0YWZmODM1YzQzOTA2YTEzY2NjYmMyNjdkYjVm", 299999688_i64)

  Transaction.new(
    "4db42cdfcffc85c86734dc1bc00adcc21aae274a3137d6a16a31162a8d6ea7b2",
    "head", # action
    [] of Transaction::Sender,
    [recipient1, recipient2, recipient3],
    [] of Transaction::Asset,
    [] of Transaction::Module,
    [] of Transaction::Input,
    [] of Transaction::Output,
    "",            # linked
    "0",           # message
    TOKEN_DEFAULT, # token
    "0",           # prev_hash
    0_i64,         # timestamp
    1,             # scaled
    TransactionKind::SLOW,
    TransactionVersion::V1
  )
end

def a_coinbase_transaction(amount : Int64)
  recipient1 = a_recipient_with_address("VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0", amount)

  Transaction.new(
    "4db42cdfcffc85c86734dc1bc00adcc21aae274a3137d6a16a31162a8d6ea7b2",
    "head", # action
    [] of Transaction::Sender,
    [recipient1],
    [] of Transaction::Asset,
    [] of Transaction::Module,
    [] of Transaction::Input,
    [] of Transaction::Output,
    "",            # linked
    "0",           # message
    TOKEN_DEFAULT, # token
    "0",           # prev_hash
    0_i64,         # timestamp
    1,             # scaled
    TransactionKind::SLOW,
    TransactionVersion::V1
  )
end

def a_recipient_with_address(address : String, amount : Int64)
  Recipient.new(address, amount)
end

def a_fixed_sender_wallet
  Wallet.new("3a133bb891f14aa755af119907bd20c7fcfd126fa187288cc2b9d626552f6802",
    "VDAwYjIxODI2NDg3MDE3YjA2YTYxOTJiYjUzMjg0MDAzZWNkZGRhZDJlYmUwNjMxYWM3NmIwMzFlYTg4MjlkMTBhMzBkZmNk",
    "VDAwZTdkZGNjYjg1NDA1ZjdhYzk1M2ExMDAzNmY5MjUyYjI0MmMwNGJjZWY4NjA3")
end

def a_fixed_signed_transaction
  sender_wallet = a_fixed_sender_wallet

  recipient_wallet = Wallet.new("7ff8c8296a62c29119f5914d0e7ae0341f13bd82967c4e25b66485ff0e2610af",
    "VDBmZmQwNzNhOTE2M2ExZThhZjYxNzcwMzI3M2EzZTJjMDRkZDZmZDljMzI2MWM3YzQyMTgwOGViMThjOWIzNmNiYjA4YmRj",
    "VDBjY2NmOGMyZmQ0MDc4NTIyNDBmYzNmOWQ3M2NlMzljODExOTBjYTQ0ZjMxMGFl")

  Transaction.new(
    "ded1ea5373f55b4e84ea9c140761ba181af31a94cc6c2bb22685b2f86639ca1e",
    "send", # action
    [a_signed_sender(sender_wallet, 1000_i64, "6fee937285f5bfb59d84d4e371ab28f6e2a9226091ef781b6039781778662b0f")],
    [a_recipient(recipient_wallet, 10_i64)],
    [] of Transaction::Asset,
    [] of Transaction::Module,
    [] of Transaction::Input,
    [] of Transaction::Output,
    "",            # linked
    "0",           # message
    TOKEN_DEFAULT, # token
    "0",           # prev_hash
    0_i64,         # timestamp
    1,             # scaled
    TransactionKind::SLOW,
    TransactionVersion::V1
  )
end

def with_difficulty(difficulty : Int32, &block)
  ENV["AX_SET_DIFFICULTY"] = "#{difficulty}"

  yield

  ENV.delete("AX_SET_DIFFICULTY")
end
