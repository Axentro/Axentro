# Copyright © 2017-2018 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "./../../spec_helper"

include Axentro::Core
include Axentro::Core::Keys

describe Address do
  it "should create an address object from a hex string" do
    address_hex = "TTBkYzI1OGY3MWY5YTNjZTU5Zjg4ZGJlNjI1ODUxNmU3OTY3MDg4NGE1MDU2YzE0"
    address = Address.new(address_hex)
    address.as_hex.should eq(address_hex)
  end

  it "should raise an error if address checksum is not valid" do
    expect_raises(Exception, "invalid generic address checksum for: invalid-address") do
      Address.new("invalid-address")
    end
  end

  it "should return the network when calling #network" do
    KeyRing.generate.address.network.should eq(MAINNET)
  end

  it "should return true for #is_valid?" do
    KeyRing.generate.address.is_valid?.should be_true
  end

  describe "Address.from(hex)" do
    it "should create an Address from an address hex" do
      address_hex = "TTBkYzI1OGY3MWY5YTNjZTU5Zjg4ZGJlNjI1ODUxNmU3OTY3MDg4NGE1MDU2YzE0"
      address = Address.from(address_hex)
      address.network.should eq(MAINNET)
      address.as_hex.should eq(address_hex)
    end

    it "should raise an error if network is invalid" do
      address_hex = Base64.strict_encode("UO-invalid-address")
      expect_raises(Exception, "invalid network: UO for address: VU8taW52YWxpZC1hZGRyZXNz") do
        Address.from(address_hex)
      end
    end

    it "should raise an error using supplied name" do
      address_hex = Base64.strict_encode("T0-invalid-address")
      expect_raises(Exception, "invalid supplied name address checksum for: VDAtaW52YWxpZC1hZGRyZXNz") do
        Address.from(address_hex, "supplied name")
      end
    end
  end
end
