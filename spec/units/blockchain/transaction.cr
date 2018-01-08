describe ::Garnet::Core::Transaction do

  it "valid?" do
    transaction = ::Garnet::Core::Transaction.new(
      "app_id",
      {
        address: "abc",
        px: "def",
        py: "ghi",
        amount: 1.0,
      },
      [{
         address: "abc",
         amount: 0.5,
       }],
      "prev_hash",
      "prev_sign",
      0.0,
      "content_hash",
    )
    transaction.valid?.should eq(true)
  end

  it "to_hash" do
    transaction = ::Garnet::Core::Transaction.new(
      "app_id",
      {
        address: "abc",
        px: "def",
        py: "ghi",
        amount: 1.0,
      },
      [{
         address: "abc",
         amount: 0.5,
       }],
      "prev_hash",
      "prev_sign",
      0.0,
      "content_hash",
    )
    transaction.to_hash
      .should eq("ea002d9a8ba6c980c767787c23d267c41b17da5d0561f410e19b6aefdff3abeb")
  end
end
