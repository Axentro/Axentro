require "./../../spec_helper.cr"
require "./../utils"

include Sushi::Core::Models
include Sushi::Core
include Units::Utils

describe Scars do

  it "woop" do
    factory = BlockFactory.new
    factory.addBlocks(3)
    factory.addBlock([
      factory.transaction_factory.make_send(10_i64),
      factory.transaction_factory.make_scars_buy_platform("domain.sc", 1000_i64)
      ])
    # factory.addBlocks(10)


 p factory.chain


  end

  describe "#get" do
    it "should return nil if the number internal domains is less than confirmations" do
      chain = [genesis_block, block_1]
      scars = Scars.new
      scars.record(chain)
      scars.get("domain1.sc").should be_nil
    end

    it "should return nil if the domain is not found" do
      chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
      scars = Scars.new
      scars.record(chain)
      scars.get("domain1.sc").should be_nil
    end

    it "should return domain info if the domain is found" do
      chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
      scars = Scars.new
      scars.record(chain)
      p scars.get("domain1.sc")
    end
  end

end


# require "./../../spec_helper.cr"
#
# include Sushi::Core::Models
# include Sushi::Core
#
# describe Scars do
#   it "buy a domain which nobody bought" do
#     scars = Scars.new
#     scars.buy("test.sc", "address", 0_i64).should be_true
#
#     domain = scars.resolve("test.sc").not_nil!
#     domain[:domain_name].should eq("test.sc")
#     domain[:address].should eq("address")
#     domain[:price].should eq(0_i64)
#     domain[:status].should eq(Models::DomainStatusResolved)
#   end
#
#   it "sell a bought domain" do
#     scars = Scars.new
#     scars.buy("test.sc", "address", 0_i64).should be_true
#     scars.sell("test.sc", "address", 100_i64).should be_true
#
#     domain = scars.resolve("test.sc").not_nil!
#     domain[:domain_name].should eq("test.sc")
#     domain[:address].should eq("address")
#     domain[:price].should eq(100_i64)
#     domain[:status].should eq(Models::DomainStatusForSale)
#   end
#
#   it "buy a domain which is for sale" do
#     scars = Scars.new
#     scars.buy("test.sc", "address", 0_i64).should be_true
#     scars.sell("test.sc", "address", 100_i64).should be_true
#     scars.buy("test.sc", "address2", 100_i64).should be_true
#
#     domain = scars.resolve("test.sc").not_nil!
#     domain[:domain_name].should eq("test.sc")
#     domain[:address].should eq("address2")
#     domain[:price].should eq(100_i64)
#     domain[:status].should eq(Models::DomainStatusResolved)
#   end
#
#   it "raise if the buying domain is not for sale" do
#     scars = Scars.new
#     scars.buy("test.sc", "address", 0_i64).should be_true
#
#     expect_raises(Exception, "domain test.sc is not for sale now") do
#       scars.buy("test.sc", "address2", 0_i64)
#     end
#   end
#
#   it "raise if the buying price is different of the sellin price" do
#     scars = Scars.new
#     scars.buy("test.sc", "address", 0_i64).should be_true
#     scars.sell("test.sc", "address", 100_i64).should be_true
#
#     expect_raises(Exception, "the price 10 is different of 100") do
#       scars.buy("test.sc", "address2", 10_i64)
#     end
#   end
#
#   it "raise if the selling domain not found" do
#     scars = Scars.new
#
#     expect_raises(Exception, "domain test.sc not found") do
#       scars.sell("test.sc", "address", 100_i64)
#     end
#   end
#
#   it "raise if the selling domain's address is different of the address" do
#     scars = Scars.new
#     scars.buy("test.sc", "address", 0_i64).should be_true
#
#     expect_raises(Exception, "domain address mismatch: address2 vs address") do
#       scars.sell("test.sc", "address2", 100_i64)
#     end
#   end
#
#   it "get an array of the sale domains" do
#     scars = Scars.new
#
#     5.times do |i|
#       scars.buy("test#{i}.sc", "address#{i}", 0_i64).should be_true
#       scars.sell("test#{i}.sc", "address#{i}", 100_i64).should be_true
#     end
#
#     sales = scars.sales
#     sales.size.should eq(5)
#     sales.each_with_index do |sale_domain, i|
#       sale_domain[:domain_name].should eq("test#{i}.sc")
#       sale_domain[:address].should eq("address#{i}")
#       sale_domain[:price].should eq(100)
#       sale_domain[:status].should eq(Models::DomainStatusForSale)
#     end
#   end
#
#   STDERR.puts "< Scars"
# end
