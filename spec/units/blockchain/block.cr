describe ::Garnet::Core::Block do

  it "to_hash" do
    block = ::Garnet::Core::Block.new(0_u32, 1.0, [] of ::Garnet::Core::Transaction, 0_u64, "abc")
    block.to_hash
      .should eq("6ef45ed9855d9ca815de8447e9fc3abbe1c7f24331597787d4cc14ba3bb0bd25")
  end

  it "merkle_tree_root" do
  end
end
