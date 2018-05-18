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
require "./../utils"

include Sushi::Core
include Hashes
include Units::Utils

describe Block do
  it "should create a genesis block (new block with no transactions)" do
    block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis")
    block.index.should eq(0)
    block.transactions.should eq([] of Transaction)
    block.nonce.should eq(0)
    block.prev_hash.should eq("genesis")
    block.merkle_tree_root.should eq("")
  end

  it "should return the header for #to_header" do
    block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis")
    block.to_header.should eq({index: 0_i64, nonce: 0_u64, prev_hash: "genesis", merkle_tree_root: ""})
  end

  describe "#calcluate_merkle_tree_root" do
    it "should return empty merkle tree root value when no transactions" do
      block = Block.new(0_i64, [] of Transaction, 0_u64, "prev_hash")
      block.calcluate_merkle_tree_root.should eq("")
    end

    it "should calculate merkle tree root when coinbase transaction" do
      coinbase_transaction = a_fixed_coinbase_transaction
      block = Block.new(1_i64, [coinbase_transaction], 1_u64, "prev_hash")
      block.calcluate_merkle_tree_root.should eq("01856aeae999909e1813961eb45d6ed6f317382d")
    end

    it "should calculate merkle tree root when 2 transactions (first is coinbase)" do
      coinbase_transaction = a_fixed_coinbase_transaction
      transaction1 = a_fixed_signed_transaction
      block = Block.new(1_i64, [coinbase_transaction, transaction1], 1_u64, "prev_hash")
      block.calcluate_merkle_tree_root.should eq("5faf746c88d29f986549a5d39d39d2a2be761a87")
    end
  end

  describe "#valid_nonce?" do
    it "should return true when valid" do
      with_factory do |block_factory|
        block = block_factory.addBlock.chain.first
        block.valid_nonce?(67_u64, 2).should be_true
      end
    end

    it "should return false when invalid" do
      with_factory do |block_factory|
        block = block_factory.addBlock.chain.first
        block.valid_nonce?(68_u64, 2).should be_false
      end
    end
  end

  describe "#valid_as_latest?" do
    context "when not a genesis block" do
      it "should be valid" do
        blockchain = blockchain_node(a_fixed_sender_wallet)
        prev_hash = blockchain.chain[0].to_hash
        coinbase_transaction = a_fixed_coinbase_transaction
        block = Block.new(1_i64, [coinbase_transaction], 60127_u64, prev_hash)
        block.valid_as_latest?(blockchain).should be_true
      end

      it "should raise an error: invalid index" do
        blockchain = blockchain_node(a_fixed_sender_wallet)
        prev_hash = blockchain.chain[0].to_hash
        block = Block.new(2_i64, [a_fixed_signed_transaction], 0_u64, prev_hash)
        expect_raises(Exception, "invalid index, 2 have to be 1") do
          block.valid_as_latest?(blockchain)
        end
      end

      it "should raise an error: invalid transaction" do
        with_factory do |block_factory, transaction_factory|
          senders = [a_sender(transaction_factory.sender_wallet, 1000_i64)]
          recipients = [a_recipient(transaction_factory.recipient_wallet, 100_i64)]

          unsigned_transaction = Transaction.new(
            Transaction.create_id,
            "send", # action
            senders,
            recipients,
            "0",           # message
            TOKEN_DEFAULT, # token
            "0",           # prev_hash
            1              # scaled
          )

          signed_transaction = unsigned_transaction.as_signed([transaction_factory.sender_wallet])

          blockchain = blockchain_node(transaction_factory.sender_wallet)
          block = Block.new(1_i64, [signed_transaction], 0_u64, "prev_hash")
          expect_raises(Exception, "actions has to be 'head' for coinbase transaction") do
            block.valid_as_latest?(blockchain)
          end
        end
      end
    end

    context "when a genesis block" do
      it "should be valid" do
        blockchain = blockchain_node(a_fixed_sender_wallet)
        block = Block.new(0_i64, [] of Transaction, 0_u64, "genesis")
        block.valid_as_latest?(blockchain).should be_true
      end

      it "should raise an error: transactions have to be empty" do
        blockchain = blockchain_node(a_fixed_sender_wallet)
        block = Block.new(0_i64, [a_fixed_signed_transaction], 0_u64, "genesis")
        expect_raises(Exception, /transactions have to be empty for genesis block/) do
          block.valid_as_latest?(blockchain)
        end
      end

      it "should raise an error: nonce has to be '0'" do
        blockchain = blockchain_node(a_fixed_sender_wallet)
        block = Block.new(0_i64, [] of Transaction, 1_u64, "genesis")
        expect_raises(Exception, "nonce has to be '0' for genesis block: 1") do
          block.valid_as_latest?(blockchain)
        end
      end

      it "should raise an error: prev_hash has to be 'genesis'" do
        blockchain = blockchain_node(a_fixed_sender_wallet)
        block = Block.new(0_i64, [] of Transaction, 0_u64, "not-genesis")
        expect_raises(Exception, "prev_hash has to be 'genesis' for genesis block: not-genesis") do
          block.valid_as_latest?(blockchain)
        end
      end
    end
  end

  describe "#valid_for?" do
    it "should return true when valid" do
      with_factory do |block_factory|
        chain = block_factory.addBlocks(2).chain
        block_factory.enable_difficulty
        block1 = chain[1]
        block2 = chain[2]

        block2.valid_for?(block1).should be_true
        block_factory.remove_difficulty
      end
    end

    it "should raise an error: mismatch index" do
      transaction1 = a_fixed_signed_transaction
      prev_block = Block.new(3_i64, [transaction1], 0_u64, "prev_hash_1")
      prev_hash = prev_block.to_hash
      block = Block.new(2_i64, [transaction1], 0_u64, prev_hash)
      expect_raises(Exception, "mismatch index for the prev block(3): 2") do
        block.valid_for?(prev_block)
      end
    end

    it "should raise an error: prev_hash does not match" do
      transaction1 = a_fixed_signed_transaction
      prev_block = Block.new(1_i64, [transaction1], 0_u64, "prev_hash_1")
      prev_hash = prev_block.to_hash
      block = Block.new(2_i64, [transaction1], 0_u64, "incorrect_prev_hash")
      expect_raises(Exception, "prev_hash is invalid: #{prev_hash} != incorrect_prev_hash") do
        block.valid_for?(prev_block)
      end
    end

    it "should raise an error: nonce is invalid" do
      transaction1 = a_fixed_signed_transaction
      prev_block = Block.new(1_i64, [transaction1], 10_u64, "prev_hash_1")
      prev_hash = prev_block.to_hash
      block = Block.new(2_i64, [transaction1], 99_u64, prev_hash)

      expect_raises(Exception, "the nonce is invalid: 99") do
        block.valid_for?(prev_block)
      end
    end

    it "should raise an error: Invalid merkle tree root" do
      # someone tried to add into block2 a duplicate of a transaction already in block 1 - but with a different amount
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(2).chain
        block_factory.enable_difficulty
        block1 = chain[1]
        block2 = chain[2]

        block2.valid_for?(block1).should eq(true)

        source_recipient = block2.transactions.first.recipients.first
        target_recipient = a_recipient_with_address(source_recipient["address"], source_recipient["amount"] + 12500_i64)
        block2.transactions.first.recipients = [target_recipient]

        expect_raises(Exception, "invalid merkle tree root: #{block2.calcluate_merkle_tree_root} != #{block2.merkle_tree_root}") do
          block2.valid_for?(block1)
          block_factory.remove_difficulty
        end
      end
    end
  end

  describe "#find_transaction" do
    it "should find a transaction when an matching one exists" do
      coinbase_transaction = a_fixed_coinbase_transaction
      block = Block.new(1_i64, [coinbase_transaction, a_fixed_signed_transaction], 0_u64, "prev_hash_1")
      block.find_transaction(coinbase_transaction.id).should eq(coinbase_transaction)
    end

    it "should return nil when cannot find a matching transaction" do
      coinbase_transaction = a_fixed_coinbase_transaction
      block = Block.new(1_i64, [coinbase_transaction, a_fixed_signed_transaction], 0_u64, "prev_hash_1")
      block.find_transaction("transaction-not-found").should be_nil
    end
  end

  STDERR.puts "< Block"
end

def a_fixed_coinbase_transaction
  recipient1 = a_recipient_with_address("VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0", 50452650_i64)
  recipient2 = a_recipient_with_address("VDBhYTYxYzk5MTQ4M2QyZmU1YTA4NzUxZjYzYWUzYzA4ZTExYTgzMjdkNWViODU2", 7500_i64)
  recipient3 = a_recipient_with_address("VDAyNTk0YjdlMTc4N2FkODRmYTU0YWZmODM1YzQzOTA2YTEzY2NjYmMyNjdkYjVm", 2500_i64)

  Transaction.new(
    "4db42cdfcffc85c86734dc1bc00adcc21aae274a3137d6a16a31162a8d6ea7b2",
    "head", # action
    [] of Transaction::Sender,
    [recipient1, recipient2, recipient3],
    "0",           # message
    TOKEN_DEFAULT, # token
    "0",           # prev_hash
    1              # scaled
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

  signed_transaction = Transaction.new(
    "ded1ea5373f55b4e84ea9c140761ba181af31a94cc6c2bb22685b2f86639ca1e",
    "send", # action
    [a_signed_sender(sender_wallet, 1000_i64, "6fee937285f5bfb59d84d4e371ab28f6e2a9226091ef781b6039781778662b0f", "c033714ab9a447ac08b7e2774b42ff894a143663147923403b2da171ffd6f7e9")],
    [a_recipient(recipient_wallet, 10_i64)],
    "0",           # message
    TOKEN_DEFAULT, # token
    "0",           # prev_hash
    1              # scaled
  )
end
