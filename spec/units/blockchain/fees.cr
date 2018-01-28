require "./../../spec_helper"

include Sushi::Core
include Sushi::Core::Fees

describe Fees do
  it "should return the correct fee for action 'send'" do
    min_fee_of_action("send").should eq(1_i64)
  end

  it "should return a general fee for an action that has no specific fee" do
    min_fee_of_action("no-specific-fee").should eq(0_i64)
  end

  STDERR.puts "< Fees"
end
