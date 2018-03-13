require "./../../spec_helper.cr"
require "./../utils"

include Sushi::Core::Models
include Sushi::Core
include Units::Utils

describe Scars do
  describe "#get" do
    it "should return nil if the number internal domains is less than confirmations" do
      with_factory do |block_factory|
        chain = block_factory.addBlock.chain
        scars = Scars.new
        scars.record(chain)
        scars.get("domain1.sc").should be_nil
      end
    end

    it "should return nil if the domain is not found" do
      with_factory do |block_factory|
        chain = block_factory.addBlocks(10).chain
        scars = Scars.new
        scars.record(chain)
        scars.get("domain1.sc").should be_nil
      end
    end

    it "should return domain info if the domain is found" do
      with_factory do |block_factory, transaction_factory|
        domain = "domain1.sc"
        chain = block_factory.addBlock([transaction_factory.make_scars_buy_platform(domain, 0_i64)]).addBlocks(10).chain
        scars = Scars.new
        scars.record(chain)

        onSuccess(scars.get(domain)) do |result|
          result["domain_name"].should eq(domain)
          result["address"].should eq(transaction_factory.sender_wallet.address)
          result["status"].should eq(0)
          result["price"].should eq(0_i64)
        end
      end
    end
  end
  STDERR.puts "< Scars"
end

def onSuccess(result, &block)
  if result.nil?
    fail("value should not be nil")
  else
    yield result
  end
end
