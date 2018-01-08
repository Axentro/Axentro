describe ::Garnet::Core::ECDSA do

  it "sign & verify" do
    secp265k1 = ::Garnet::Core::ECDSA::Secp256k1.new
    key_pair = secp265k1.create_key_pair

    message = "message"
    signed = secp265k1.sign(key_pair[:secret_key], message)

    secp265k1.verify(key_pair[:public_key], message, signed[0], signed[1]).should eq(true)
  end
end
