require "./../../spec_helper"
require "./../utils"

include Sushi::Core
include Sushi::Core::Keys

describe Address do
  it "should create an address object from a hex string" do
    address_hex = "TTBkYzI1OGY3MWY5YTNjZTU5Zjg4ZGJlNjI1ODUxNmU3OTY3MDg4NGE1MDU2YzE0"
    address = Address.new(address_hex)
    address.as_hex.should eq(address_hex)
  end

  it "should raise an error if address checksum is not valid" do
    expect_raises(Exception, "Invalid address checksum for: invalid-address") do
      Address.new("invalid-address")
    end
  end

  it "should return the network when calling #network" do
    Keys.generate.address.network.should eq({prefix: "M0", name: "mainnet"})
  end

  it "should return true for #is_valid?" do
    # NOTE a return value of false is not possible as Address can't be created when invalid
    Keys.generate.address.is_valid?.should be_true
  end
  STDERR.puts "< Keys::Address"
end
