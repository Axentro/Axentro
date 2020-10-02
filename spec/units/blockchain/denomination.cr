# Copyright © 2017-2020 The Axentro Core developers
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

include Units::Utils
include Axentro::Core
include Axentro::Common::Denomination

describe Axentro::Common::Denomination do
  it "should convert string value into Int64 for scale_i64" do
    scale_i64("0.0001").should eq(10000)
  end

  it "should convert an Int64 value into a scaled string" do
    scale_decimal(10000.to_i64).should eq("0.0001")
  end
end
