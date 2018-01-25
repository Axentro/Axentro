require "./../../spec_helper"
require "./../utils"

include Sushi::Core::Models
include Units::Utils
include Sushi::Core
include Hashes

describe Block do

  it "should create a genesis block (new block with no transactions)" do
    block = Block.new(0.to_i64, [] of Transaction,  0.to_u64, "genesis")
    block.index.should eq(0)
    block.transactions.should eq([] of Transaction)
    block.nonce.should eq(0)
    block.prev_hash.should eq("genesis")
    block.merkle_tree_root.should eq("")
  end

  it "should return the header for #to_header" do
    block = Block.new(0.to_i64, [] of Transaction,  0.to_u64, "genesis")
    block.to_header.should eq({index: 0_i64, nonce: 0_u64, prev_hash: "genesis", merkle_tree_root: ""})
  end

  describe "#calcluate_merkle_tree_root" do

    it "should return empty merkle tree root value when no transactions" do
      block = Block.new(0.to_i64, [] of Transaction,  0.to_u64, "genesis")
      block.calcluate_merkle_tree_root.should eq("")
    end

    it "should calculate merkle tree root when coinbase transaction" do
      coinbase_transaction = a_coinbase_transaction
      block = Block.new(0.to_i64, [coinbase_transaction],  0.to_u64, "genesis")
      block.calcluate_merkle_tree_root.should eq(expected_merkle_tree_root_1([coinbase_transaction]))
    end

    it "should calculate merkle tree root when 2 transactions (first is coinbase)" do
      coinbase_transaction = a_coinbase_transaction
      transaction1 = an_unsigned_transaction
      block = Block.new(0.to_i64, [coinbase_transaction, transaction1],  0.to_u64, "genesis")
      p expected_merkle_tree_root([transaction1])
      block.calcluate_merkle_tree_root.should eq("")
    end

  end

end

def expected_merkle_tree_root_1(transactions)
  current_hashes = transactions.map { |tx| tx.to_hash }
  ripemd160(current_hashes[0]).hexstring
end

def a_coinbase_transaction
  recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)
  Transaction.new(
    Transaction.create_id,
    "head", # action
    [] of Sender,
    [ a_recipient(recipient_wallet, 10000.00) ],
    "0", # message
    "0", # prev_hash
    "0", # sign_r
    "0", # sign_s
  )
end

def an_unsigned_transaction
  a_signed_transaction.as_unsigned
end

def a_signed_transaction
  sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
  recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)

  unsigned_transaction = Transaction.new(
    Transaction.create_id,
    "send", # action
    [ a_sender(sender_wallet, 1000.00) ],
    [ a_recipient(recipient_wallet, 10.00) ],
    "0", # message
    "0", # prev_hash
    "0", # sign_r
    "0", # sign_s
  )

  blockchain = Blockchain.new(sender_wallet)
  signature = sign(sender_wallet, unsigned_transaction)
  unsigned_transaction.signed(signature[:r],signature[:s])
end
