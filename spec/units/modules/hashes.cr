include ::Garnet::Core::Hashes

describe ::Garnet::Core::Hashes do

  it "sha256" do
    data = "abcd"

    sha256(data)
      .should eq("88d4266fd4e6338d13b845fcf289579d209c897823b9217da3e161936f031589")

    sha256_from_hexstring(data)
      .should eq("123d4c7ef2d1600a1b3a0f6addc60a10f05a3495c9409f2ecbf4cc095d000a6b")
  end

  it "ripemd160" do
    data = "abcd"

    ripemd160(data)
      .should eq("2e7e536fd487deaa943fda5522d917bdb9011b7a")

    ripemd160_from_hexstring(data)
      .should eq("a21c2817130deaa1105afb3b858dbd219ee2da44")
  end
end
