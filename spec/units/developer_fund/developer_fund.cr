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

include Sushi::Core

describe DeveloperFund do
  it "should successfully parse the developer fund yml file and get the contents" do
    DeveloperFund.validate("#{__DIR__}/../../utils/data/developer_fund.yml")
  end

  it "should return nil if nil is supplied for path" do
    DeveloperFund.validate(nil).should be_nil
  end

  it "should raise an invalid developer fund file if the file extension is not .yml" do
    expect_raises(Exception, "Developer fund input file must be a valid .yml file - you supplied developer_fund.txt") do
      DeveloperFund.validate("developer_fund.txt")
    end
  end

  it "should raise an error if any of the supplied addresses are invalid" do
    expect_raises(Exception, "The supplied address: invalid_address is invalid") do
      DeveloperFund.validate("#{__DIR__}/../../utils/data/developer_fund_invalid.yml")
    end
  end

  it "should raise an error if any of the supplied amounts are invalid" do
    expect_raises(Exception, "The supplied amount: -40 for address: VDA2NjU5N2JlNDA3ZDk5Nzg4MGY2NjY5YjhhOTUwZTE2M2VmNjM5OWM2M2EyMWQz - the amount is out of range") do
      DeveloperFund.validate("#{__DIR__}/../../utils/data/developer_fund_invalid_amounts.yml")
    end
  end

  it "should generate the developer fund transactions" do
    developer_fund = DeveloperFund.validate("#{__DIR__}/../../utils/data/developer_fund.yml")
    expected_recipients = [{address: "VDA2NjU5N2JlNDA3ZDk5Nzg4MGY2NjY5YjhhOTUwZTE2M2VmNjM5OWM2M2EyMWQz", amount: 500000000000}, {address: "VDAyMzEwODI2NmE1MWJiYTAxOTA2YjE0NzRjYTRjYjllYTk0ZDZhYmJhZGU3MmIz", amount: 900000000000}]
    DeveloperFund.transactions(developer_fund.not_nil!.get_config).flat_map(&.recipients).sort_by(&.["amount"]).should eq(expected_recipients)
  end

  STDERR.puts "< DeveloperFund"
end
