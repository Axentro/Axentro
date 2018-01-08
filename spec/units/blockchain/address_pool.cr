describe ::Garnet::Core::AddressPool do

  it "change" do
    address_pool = ::Garnet::Core::AddressPool.new
    address_pool.get("abc").should eq(0.0)
    address_pool.change("abc", 0.1)
    address_pool.get("abc").should eq(0.1)
    address_pool.change("abc", 0.1)
    address_pool.get("abc").should eq(0.2)
    address_pool.change("abc", -0.1)
    address_pool.get("abc").should eq(0.1)
  end
end
