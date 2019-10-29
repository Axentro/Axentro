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

require "./../../spec_helper"

include Sushi::Core
include Block
include Hashes
include Units::Utils

NODE_ADDRESS = "VDA2NjU5N2JlNDA3ZDk5Nzg4MGY2NjY5YjhhOTUwZTE2M2VmNjM5OWM2M2EyMWQz"

describe SlowBlock do
  it "should create a genesis block (new block with no transactions)" do
    block = SlowBlock.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 3_i32, NODE_ADDRESS)
    block.index.should eq(0)
    block.transactions.should eq([] of Transaction)
    block.nonce.should eq(0)
    block.prev_hash.should eq("genesis")
    block.merkle_tree_root.should eq("")
  end

  it "should return the header for #to_header" do
    block = SlowBlock.new(0_i64, [] of Transaction, 0_u64, "genesis", 0_i64, 3_i32, NODE_ADDRESS)
    block.to_header.should eq({index: 0_i64, nonce: 0_u64, prev_hash: "genesis", merkle_tree_root: "", timestamp: 0_i64, difficulty: 3})
  end

  describe "#calculate_merkle_tree_root" do
    it "should return empty merkle tree root value when no transactions" do
      block = SlowBlock.new(0_i64, [] of Transaction, a_nonce, "prev_hash", 0_i64, 3_i32, NODE_ADDRESS)
      block.calculate_merkle_tree_root.should eq("")
    end

    it "should calculate merkle tree root when coinbase transaction" do
      coinbase_transaction = a_fixed_coinbase_transaction
      block = SlowBlock.new(2_i64, [coinbase_transaction], 1_u64, "prev_hash", 0_i64, 3_i32, NODE_ADDRESS)
      block.calculate_merkle_tree_root.should eq("f1a5402b71f528bc6d34dfc2e1973eea822db0e4")
    end

    it "should calculate merkle tree root when 2 transactions (first is coinbase)" do
      coinbase_transaction = a_fixed_coinbase_transaction
      transaction1 = a_fixed_signed_transaction
      block = SlowBlock.new(2_i64, [coinbase_transaction, transaction1], 1_u64, "prev_hash", 0_i64, 3_i32, NODE_ADDRESS)
      block.calculate_merkle_tree_root.should eq("f8443333f72316e88b954cbfdb6b61e8be0fc5cf")
    end
  end

  describe "#valid_nonce?" do
    it "should return true when valid" do
      with_factory do |block_factory|
        block = block_factory.add_slow_block.chain.first.as(SlowBlock)
        block.nonce = a_nonce
        block.valid_nonce?(0).should eq(0)
      end
    end

    it "should less that 3 when invalid" do
      with_factory do |block_factory|
        block = block_factory.add_slow_block.chain.first.as(SlowBlock)
        block.nonce = a_nonce
        block.valid_nonce?(2).should be < 3
      end
    end
  end

  describe "#valid_as_latest?" do
    it "should return true when valid" do
      with_factory do |block_factory|
        chain = block_factory.add_slow_blocks(1).chain
        prev_hash = chain[1].to_hash
        timestamp = chain[1].timestamp
        block = SlowBlock.new(4_i64, [a_coinbase_transaction(1199998747_i64)], a_nonce, prev_hash, timestamp, 0_i32, NODE_ADDRESS)
        block.valid_as_latest?(block_factory.blockchain, false).should be_true
      end
    end

    it "should raise invalid mismatch if there is an index mismatch with the prev block" do
      with_factory do |block_factory|
        chain = block_factory.add_slow_blocks(1).chain
        prev_hash = chain[1].to_hash
        timestamp = chain[1].timestamp
        block = SlowBlock.new(98_i64, [a_coinbase_transaction(1199969322_i64)], a_nonce, prev_hash, timestamp, 1_i32, NODE_ADDRESS)

        expect_raises(Exception, "Index Mismatch: the current block index: 98 should match the lastest slow block index: 4") do
          block.valid_as_latest?(block_factory.blockchain, false)
        end
      end
    end

    it "should raise error if prev hash is invalid" do
      with_factory do |block_factory|
        chain = block_factory.add_slow_blocks(1).chain
        prev_hash = "invalid"
        timestamp = chain[1].timestamp
        block = SlowBlock.new(4_i64, [a_coinbase_transaction(1199998747_i64)], a_nonce, prev_hash, timestamp, 0_i32, NODE_ADDRESS)

        expect_raises(Exception, /prev_hash is invalid:/) do
          block.valid_as_latest?(block_factory.blockchain, false)
        end
      end
    end

    it "should raise error if timestamp is invalid because is smaller than prev timestamp" do
      with_factory do |block_factory|
        chain = block_factory.add_slow_blocks(1).chain
        prev_hash = chain[1].to_hash
        timestamp = chain[1].timestamp - 10000000
        block = SlowBlock.new(4_i64, [a_coinbase_transaction(1199998747_i64)], a_nonce, prev_hash, timestamp, 0_i32, NODE_ADDRESS)

        expect_raises(Exception, /Invalid Timestamp:/) do
          block.valid_as_latest?(block_factory.blockchain, false)
        end
      end
    end

    it "should raise error if timestamp is invalid because is bigger than next timestamp" do
      with_factory do |block_factory|
        chain = block_factory.add_slow_blocks(1).chain
        prev_hash = chain[1].to_hash
        timestamp = chain[1].timestamp + 10000000
        block = SlowBlock.new(4_i64, [a_coinbase_transaction(1199998747_i64)], a_nonce, prev_hash, timestamp, 0_i32, NODE_ADDRESS)

        expect_raises(Exception, /Invalid Timestamp:/) do
          block.valid_as_latest?(block_factory.blockchain, false)
        end
      end
    end

    it "should raise error if merkle tree root is invalid" do
      with_factory do |block_factory|
        chain = block_factory.add_slow_blocks(1).chain
        prev_hash = chain[1].to_hash
        timestamp = chain[1].timestamp
        block = SlowBlock.new(4_i64, [a_coinbase_transaction(1199998747_i64)], a_nonce, prev_hash, timestamp, 0_i32, NODE_ADDRESS)
        block.merkle_tree_root = "invalid"
        expect_raises(Exception, "Invalid Merkle Tree Root: (expected invalid but got 616efa391561ec059a6558eca2215398ac051fb8)") do
          block.valid_as_latest?(block_factory.blockchain, false)
        end
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
        block = chain.first.as(SlowBlock)
        block.nonce = 1_u64
        expect_raises(Exception, "nonce has to be '0' for genesis block: 1") do
          block.valid?(block_factory.blockchain, false)
        end
      end
    end

    it "should raise error if prev hash is not 'genesis'" do
      with_factory do |block_factory|
        chain = block_factory.blockchain.chain
        block = chain.first.as(SlowBlock)
        block.prev_hash = "invalid"
        expect_raises(Exception, "prev_hash has to be 'genesis' for genesis block: invalid") do
          block.valid?(block_factory.blockchain, false)
        end
      end
    end

    it "should raise error if difficulty is not 3" do
      with_factory do |block_factory|
        chain = block_factory.blockchain.chain
        block = chain.first.as(SlowBlock)
        block.difficulty = 99
        expect_raises(Exception, "difficulty has to be '17' for genesis block: 99") do
          block.valid?(block_factory.blockchain, false)
        end
      end
    end
  end

  describe "#find_transaction" do
    it "should find a transaction when an matching one exists" do
      coinbase_transaction = a_fixed_coinbase_transaction
      block = SlowBlock.new(2_i64, [coinbase_transaction, a_fixed_signed_transaction], a_nonce, "prev_hash_1", 0_i64, 3_i32, NODE_ADDRESS)
      block.find_transaction(coinbase_transaction.id).should eq(coinbase_transaction)
    end

    it "should return nil when cannot find a matching transaction" do
      coinbase_transaction = a_fixed_coinbase_transaction
      block = SlowBlock.new(2_i64, [coinbase_transaction, a_fixed_signed_transaction], a_nonce, "prev_hash_1", 0_i64, 3_i32, NODE_ADDRESS)
      block.find_transaction("transaction-not-found").should be_nil
    end
  end
end

def a_nonce
  5995816054692193019_u64
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
    "0",           # message
    TOKEN_DEFAULT, # token
    "0",           # prev_hash
    0_i64,         # timestamp
    1,             # scaled
    TransactionKind::SLOW
  )
end

def a_coinbase_transaction(amount : Int64)
  recipient1 = a_recipient_with_address("VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0", amount)

  Transaction.new(
    "4db42cdfcffc85c86734dc1bc00adcc21aae274a3137d6a16a31162a8d6ea7b2",
    "head", # action
    [] of Transaction::Sender,
    [recipient1],
    "0",           # message
    TOKEN_DEFAULT, # token
    "0",           # prev_hash
    0_i64,         # timestamp
    1,             # scaled
    TransactionKind::SLOW
  )
end

def a_recipient_with_address(address : String, amount : Int64)
  {address: address,
   amount:  amount}
end

def a_fixed_sender_wallet
  Wallet.new("f3df738b74757c81499e0780e93a43a7e6fca21909709163cf3f90223b350c55dc203ab377fef06529cfa9a471ba4bec3e8cbd91ab811728614524adbc1aa6c3",
    "TTBkN2I1YmMwZDI0YTYxNDRiZDQ5YWZmMmYyMDIzMGNkZDBlMWMwZDVlNzdiZjc3MzhhZGU0N2I4YjZhYzZmYWQ5OGIyNWQ0",
    "VDAyNTk0YjdlMTc4N2FkODRmYTU0YWZmODM1YzQzOTA2YTEzY2NjYmMyNjdkYjVm")
end

def a_fixed_signed_transaction
  sender_wallet = a_fixed_sender_wallet

  recipient_wallet = Wallet.new("2ee4c6a6197e334c3de5b6384af495ae08093e3aceb4122ce7270a072caba1a9cd119eb7bc59adcd925123deba2fba44f70aefcd189c6c145cd2d00290a385cf",
    "TTA0MGQyMjc2ODMxNmE2MzlmZTNmNDZmNzRlYTU0NDFmNDM3MGY0MDBmNzU3NGVlMDE2OThkNDM4MjcxMTk0NzY4NjM4NWVj",
    "TTA4ZGViYmM1NTdiNTkyNmU1MmUwZmQ5NThkZWQ1M2E1ODE5NjU2NDg1OWM2MWQw")

  Transaction.new(
    "ded1ea5373f55b4e84ea9c140761ba181af31a94cc6c2bb22685b2f86639ca1e",
    "send", # action
    [a_signed_sender(sender_wallet, 1000_i64, "6fee937285f5bfb59d84d4e371ab28f6e2a9226091ef781b6039781778662b0f", "c033714ab9a447ac08b7e2774b42ff894a143663147923403b2da171ffd6f7e9")],
    [a_recipient(recipient_wallet, 10_i64)],
    "0",           # message
    TOKEN_DEFAULT, # token
    "0",           # prev_hash
    0_i64,         # timestamp
    1,             # scaled
    TransactionKind::SLOW
  )
end

def with_difficulty(difficulty : Int32, &block)
  ENV["SC_SET_DIFFICULTY"] = "#{difficulty}"

  yield

  ENV.delete("SC_SET_DIFFICULTY")
end
