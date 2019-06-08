# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "./../../spec_helper"
require "./../utils"

include Sushi::Core

describe Premine do

  it "should successfully parse the premine yml file and get the contents" do
      Premine.validate("#{__DIR__}/../utils/data/premine.yml")
  end

  it "should raise an invalid premine file if the file extension is not .yml" do
    expect_raises(Exception, "Premine input file must be a valid .yml file - you supplied premine.txt") do
      Premine.validate("premine.txt")
    end
  end

  it "should raise an error if any of the supplied addresses are invalid" do
    expect_raises(Exception, "The supplied address: invalid_address is invalid") do
      Premine.validate("#{__DIR__}/../utils/data/premine-invalid.yml")
    end
  end
    STDERR.puts "< Premine"
end
