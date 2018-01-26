require "./../../spec_helper"

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

end
