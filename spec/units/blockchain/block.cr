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
      block = Block.new(0.to_i64, [] of Transaction,  0.to_u64, "prev_hash")
      block.calcluate_merkle_tree_root.should eq("")
    end

    it "should calculate merkle tree root when coinbase transaction" do
      coinbase_transaction = a_fixed_coinbase_transaction
      block = Block.new(1.to_i64, [coinbase_transaction],  1.to_u64, "prev_hash")
      block.calcluate_merkle_tree_root.should eq("892b10c82be3d98e614bf2f48b7513d8e1200201")
    end

    it "should calculate merkle tree root when 2 transactions (first is coinbase)" do
      coinbase_transaction = a_fixed_coinbase_transaction
      transaction1 = a_fixed_signed_transaction
      block = Block.new(1.to_i64, [coinbase_transaction, transaction1],  1.to_u64, "prev_hash")
      block.calcluate_merkle_tree_root.should eq("4fec03c8fffc18d05beb8025630882e0bf8290f5")
    end

  end

  describe "#valid_nonce?" do

    it "should return true when valid" do
      coinbase_transaction = a_fixed_coinbase_transaction
      block = Block.new(1.to_i64, [coinbase_transaction],  1.to_u64, "prev_hash")
      block.valid_nonce?(44181.to_u64, 4).should be_true
    end

    it "should return false when invalid" do
      coinbase_transaction = a_fixed_coinbase_transaction
      block = Block.new(1.to_i64, [coinbase_transaction],  1.to_u64, "prev_hash")
      block.valid_nonce?(1.to_u64).should be_false
    end
  end

  describe "#valid_as_latest?" do

    context "when not a genesis block" do

      it "should be valid" do
        transaction1 = a_fixed_signed_transaction
        block = Block.new(1.to_i64, [transaction1],  60127.to_u64, "5396e18efa80a8e891c417fff862d7cad171465e65bc4b4e5e1c1c3ab0aeb88f")
        blockchain = Blockchain.new(a_fixed_sender_wallet)
        block.valid_as_latest?(blockchain).should be_true
      end

      it "should raise an error: Invalid index" do
        blockchain = Blockchain.new(a_fixed_sender_wallet)
        prev_hash = blockchain.chain[0].to_hash
        block = Block.new(2.to_i64, [a_fixed_signed_transaction],  0.to_u64, prev_hash)
        expect_raises(Exception, "Invalid index, 2 have to be 1") do
          block.valid_as_latest?(blockchain)
        end
      end

    end

    context "when a genesis block" do

      it "should be valid" do
        blockchain = Blockchain.new(a_fixed_sender_wallet)
        block = Block.new(0.to_i64, [] of Transaction,  0.to_u64, "genesis")
        block.valid_as_latest?(blockchain).should be_true
      end

      it "should raise an error: Transactions have to be empty" do
        blockchain = Blockchain.new(a_fixed_sender_wallet)
        block = Block.new(0.to_i64, [a_fixed_signed_transaction],  0.to_u64, "genesis")
        expect_raises(Exception, /Transactions have to be empty for genesis block/) do
          block.valid_as_latest?(blockchain)
        end
      end

      it "should raise an error: nonce has to be '0'" do
        blockchain = Blockchain.new(a_fixed_sender_wallet)
        block = Block.new(0.to_i64, [] of Transaction,  1.to_u64, "genesis")
        expect_raises(Exception, "nonce has to be '0' for genesis block: 1") do
          block.valid_as_latest?(blockchain)
        end
      end

      it "should raise an error: prev_hash has to be 'genesis'" do
        blockchain = Blockchain.new(a_fixed_sender_wallet)
        block = Block.new(0.to_i64, [] of Transaction,  0.to_u64, "not-genesis")
        expect_raises(Exception, "prev_hash has to be 'genesis' for genesis block: not-genesis") do
          block.valid_as_latest?(blockchain)
        end
      end

    end

  end

  describe "#valid_for?" do

    # def valid_for?(prev_block : Block) : Bool
    #   raise "Mismatch index for the prev block(#{prev_block.index}): #{@index}" if prev_block.index + 1 != @index
    #   raise "prev_hash is invalid: #{prev_block.to_hash} != #{@prev_hash}" if prev_block.to_hash != @prev_hash
    #   raise "The nonce is invalid: #{@nonce}" if !prev_block.valid_nonce?(@nonce)
    #
    #   merkle_tree_root = calcluate_merkle_tree_root
    #   raise "Invalid merkle tree root: #{merkle_tree_root} != #{@merkle_tree_root}" if merkle_tree_root != @merkle_tree_root
    #
    #   true
    # end
    # it "should return true when valid" do
    #   c = 0.to_u64
    #   loop do
    #     transaction1 = a_fixed_signed_transaction
    #     prev_block = Block.new(1.to_i64, [transaction1],  0.to_u64, "prev_hash_1")
    #     prev_hash = prev_block.to_hash
    #     block = Block.new(2.to_i64, [transaction1],  483052.to_u64, prev_hash)
    #     begin
    #       v = block.valid_for?(prev_block)
    #       p c
    #       c = c + 1
    #     rescue
    #       puts "rescue: #{c}"
    #       c = c + 1
    #     end
    #   end
    # end

    it "should raise an error: mismatch index" do
      transaction1 = a_fixed_signed_transaction
      prev_block = Block.new(3.to_i64, [transaction1],  0.to_u64, "prev_hash_1")
      prev_hash = prev_block.to_hash
      block = Block.new(2.to_i64, [transaction1],  0.to_u64, prev_hash)
      expect_raises(Exception, "Mismatch index for the prev block(3): 2") do
        block.valid_for?(prev_block)
      end
    end

    it "should raise an error: prev_hash does not match" do
      transaction1 = a_fixed_signed_transaction
      prev_block = Block.new(1.to_i64, [transaction1],  0.to_u64, "prev_hash_1")
      prev_hash = prev_block.to_hash
      block = Block.new(2.to_i64, [transaction1],  0.to_u64, "incorrect_prev_hash")
      expect_raises(Exception, "prev_hash is invalid: #{prev_hash} != incorrect_prev_hash") do
        block.valid_for?(prev_block)
      end
    end

    it "should raise an error: nonce is invalid" do
      transaction1 = a_fixed_signed_transaction
      prev_block = Block.new(1.to_i64, [transaction1],  0.to_u64, "prev_hash_1")
      prev_hash = prev_block.to_hash
      block = Block.new(2.to_i64, [transaction1],  0.to_u64, prev_hash)
      expect_raises(Exception, "The nonce is invalid: 0") do
        block.valid_for?(prev_block)
      end
    end

    # it "should raise an error: invalid merkle tree root" do
    #   coinbase_transaction1 = a_fixed_coinbase_transaction
    #   coinbase_transaction2 = a_fixed_coinbase_transaction_2
    #
    #   prev_block = Block.new(1.to_i64, [coinbase_transaction1],  0.to_u64, "prev_hash_1")
    #   prev_hash = prev_block.to_hash
    #   block = Block.new(2.to_i64, [coinbase_transaction2],  0.to_u64, prev_hash)
    #
    # p prev_block.to_header
    # p block.to_header
    #
    #   # # expect_raises(Exception, "The nonce is invalid: 0") do
    #   block.valid_for?(prev_block)
    #   # # end
    # end

  end

end

def a_fixed_coinbase_transaction
  recipient_wallet = Wallet.new("MTE0OTM2NTgxNjk4OTc2OTcyOTkyNjc3ODIxMjAzMDE3NjMyODM3OTYyNDgyMjM1NTA1ODczOTU0OTQ3NDY3MzU5MjY1ODQxOTg2NDUxNjMxMzg4NzY1MTA3OTg4NTk1NTEzMzc5MzgzMTEwNzY3NTUzNzg3NDY4MTU4MzkwNDE4MTUwNjM3NzMyODY0NDkwMjE4NTMwMTA4NjA=",
                      "NTM0NDE5MjcyNTEyMzU1Mzg4MTU1ODE3NTM3NDc4NDk2NjYwMzkwNDQ5MDA4Nzg3MzI5NjUxOTg1NjcxMDY0MjUwMDAwOTQ2NTE5NDU=",
                      "ODk5MjU3NDYwMTc5MzIzMTAxNDMyMDU5MjE2NzkwNzc3OTEyMDE5NjEyOTA4MTg5MzA1NzgzMzk3MjQzMzQ5MjcyNDY4OTkyMzkxNjQ=",
                      "VDBkMzkzY2I1MDBmMDVjYWZiNGVkNjE4YzY2ZjZiNjEwZGNlMWYzZjA4M2MxOGMy")
  Transaction.new(
    "0fdb264fc242318b6815afa9ea00ef26511d67ee3c510cca2e4f27206a5ee18a",
    "head", # action
    [] of Sender,
    [ a_recipient(recipient_wallet, 10000.00) ],
    "0", # message
    "0", # prev_hash
    "0", # sign_r
    "0", # sign_s
  )
end

def a_fixed_coinbase_transaction_2
  recipient_wallet = Wallet.new("ODQyNDQzNDE4NzE1ODk1MTAwNzc2MTgwMTgyNTE5NTUyODY3NDA3NDg3ODczNjI2NDQyMTUyMjE2Mjc3Mjk3MTI0NTExMTk1MTU3Njg2Njk4NDg1MzA0MjgwODE2MTY0Mjk4NTk1NTAzOTE1MDkxMTA5MTAwMzI3OTgxMDAyMDM4MTIxNDEyNjgwNjM2OTQwODc5MDA0NDM0Mg==",
                      "OTMwOTEwNjUwMTE0NjkxOTUzNDY2NjQ4MDMxMzk0MjQxODAxMzQ1NjY5Njc2OTQ2NzMwNTIxMjA4MzI4MjY5NzA3NjU5MzgxODU2MDc=",
                      "NDg4MjA2MDE4NTk5NTYwNTU3MTk1NTE0NzE1NDAwMDI2Nzg5NTI2NjM0NTYzOTUwMTM5NzU2MDIxNTk4ODcyNzM5NDM0ODA2MTAxMDg=",
                      "VDA2ODA1NGQ4MTkzNDY5Zjc5NDM5MDljMGEyOGRiNWRmZjY2Mzk4NjYzNzA4Njhj")
  Transaction.new(
    "cb6ab50f4579e725aa7ad43fd961e82b9056273bb084bf87b3436f085991ef8d",
    "head", # action
    [] of Sender,
    [ a_recipient(recipient_wallet, 10000.00) ],
    "0", # message
    "0", # prev_hash
    "0", # sign_r
    "0", # sign_s
  )
end

def a_fixed_unsigned_transaction
  a_signed_transaction.as_unsigned
end

def a_fixed_sender_wallet
  Wallet.new("ODI1MTY3NzY2NTA2NTYyMjQwNTM3NjM3NTQ1NjEzMTIyNzI3NDA3MTU0NjUxMDU2NjY3MjY2NTYyNTIxNjAwMDI4MTMxNDY3NTk0MTMxMjQ5NjU3MjcwNjQ2MDUzMTU0MjE4MTg5Mzg3NzI4NjU5MjEwMzM0NDcyNjg1NDY5MjQ0NTEwNzQxMzU5MzkzNjIxNDMzNjMyMTA2NA==",
                      "ODQ3MjA0OTg1OTk2Mjc3MzY3NjIxMzAxMTEwMzIxMjI1NTk2Mjc1OTgzMjQ5MDYwNTgwMzUzMDcxMzg4MTk1NDQ3NDUwNDg1NDEwNzQ=",
                      "MjE1NjcyMjkyNTU1NjI5Mzg4NzgxNDg4MzA1ODk4NzQ4MDU2ODY3OTI4NjQ5MzcwNDg3MzQzNDkxMjcxMTc3MTUwNjQzNTkyOTAzMTU=",
                      "VDAyMWQyNDk3YTVjZmFlNGNhMmU3ZDFmNzcyMTdhNDNlM2VjOWU2MGVjMWM3NjY2")
end

def a_fixed_signed_transaction
  sender_wallet = a_fixed_sender_wallet

  recipient_wallet = Wallet.new("MTMwNzg1MjY3Nzk5Nzg3NTUxMDM2NTY0MDkxODMxNDQzMzE5MDg3NjEzMTY1NDg5MTY2NTAyMjcxMzUxMDgxMzA0ODM2MDkyOTA5MTgwMjMxNTk1NDYwNDc4NDAyNzYwMDAyMjUwMzI2ODA5NDc2OTM2NTI0MTQ5MzIyNDI0NDY4MjI5MDEzMDM1OTA2MDg2ODE1MjE3MzU3MTk=",
                      "ODYzMTIyOTk1MjE4Mzk0NDE5ODUxNjMyOTkzMTQ5MjM5NjE2MDgyMjc5Mzg2OTcyNzkxMzYxNDc4MzU2OTY3MzcyODI4Mjg3MTM0OTQ=",
                      "MzIzMzQyMTI3NDEzNDM2NjQwMzg1Njc0MDY5ODg3ODk3MTU0MTQ5NTU2OTc5MjM0ODI4ODA1ODcwNDM0NTg3ODkzOTg4MDc4MTEwMDI=",
                      "VDBlMWQ2YTYyYTZiMTVjZjc1MTQ2NDJlMjgwNjA5ZTMyOGU3NTE5YTRhMWI3NjY1")

  unsigned_transaction = Transaction.new(
    "ded1ea5373f55b4e84ea9c140761ba181af31a94cc6c2bb22685b2f86639ca1e",
    "send", # action
    [ a_sender(sender_wallet, 1000.00) ],
    [ a_recipient(recipient_wallet, 10.00) ],
    "0", # message
    "0", # prev_hash
    "0", # sign_r
    "0", # sign_s
  )

  unsigned_transaction.signed("cd5927cdc4cf789af690fb5dcd8fd8ec64e9155d9cb025ed93962d686b5d823a","ef991d40c9a74079ae64c3a351f733134fc50fe92628f66f3b97a42610521c06")
end
