describe ::Garnet::Core::Blockchain do

  it "valid_nonce?" do
    blockchain = ::Garnet::Core::Blockchain.new
    blockchain.valid_nonce?(32414_u64).should eq(false)
    blockchain.valid_nonce?(32415_u64).should eq(true)
    blockchain.valid_nonce?(32416_u64).should eq(false)
  end
end
