describe ::Garnet::Core::Wallet do

  it "public_key_to_address" do
    secp256k1 = ::Garnet::Core::ECDSA::Secp256k1.new

    x = BigInt.new("84651815718227144943249488898884269123250332096266176275392474856200275174552", base: 10)
    y = BigInt.new("102500659786094142824704517394540649631328072547514578449247205420793026826658", base: 10)

    point = ::Garnet::Core::ECDSA::Point.new(secp256k1, x, y)

    ::Garnet::Core::Wallet.public_key_to_address(point)
      .should eq("MDA4MzUwMGRhMmM5ODE1Y2IwNTRkNjNmZGI0MGVkYzE1NTYwNTVjNTkwYzlhOTc3")
  end

  it "valid_checksum?" do
    ::Garnet::Core::Wallet.valid_checksum?("MDA4MzUwMGRhMmM5ODE1Y2IwNTRkNjNmZGI0MGVkYzE1NTYwNTVjNTkwYzlhOTc3")
      .should eq(true)
    ::Garnet::Core::Wallet.valid_checksum?("MDA4MzUwMGRhMmM5ODE1Y2IwNTRkNjNmZGI0MGVkYzE1NTYwNTVjNTkwYzlhOTc2")
      .should eq(false)
    ::Garnet::Core::Wallet.valid_checksum?("MDA4MzUwMGRhMmM5ODE1Y2IwNTRkNjNmZGI0MGVkYzE1NTYwNTVjNTkwYzlhOTc")
      .should eq(false)
  end

  it "address_version" do
    ::Garnet::Core::Wallet.address_version("MDA4MzUwMGRhMmM5ODE1Y2IwNTRkNjNmZGI0MGVkYzE1NTYwNTVjNTkwYzlhOTc3")
      .should eq("00")
  end
end
