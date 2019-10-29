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
include Units::Utils
include Sushi::Core::DApps::BuildIn
include Sushi::Core::Controllers

describe Rejects do
  it "should perform #setup" do
    with_factory do |block_factory, _|
      rejects = Rejects.new(block_factory.add_slow_block.blockchain)
      rejects.setup.should be_nil
    end
  end
  it "should perform #transaction_actions" do
    with_factory do |block_factory, _|
      rejects = Rejects.new(block_factory.add_slow_block.blockchain)
      rejects.transaction_actions.size.should eq(0)
    end
  end
  it "should perform #transaction_related?" do
    with_factory do |block_factory, _|
      rejects = Rejects.new(block_factory.add_slow_block.blockchain)
      rejects.transaction_related?("action").should be_false
    end
  end
  it "should perform #valid_transaction?" do
    with_factory do |block_factory, _|
      chain = block_factory.add_slow_blocks(2).chain
      rejects = Rejects.new(block_factory.blockchain)
      rejects.valid_transaction?(chain.last.transactions.first, chain.last.transactions).should be_true
    end
  end
  it "should perform #record" do
    with_factory do |block_factory, _|
      chain = block_factory.add_slow_blocks(2).chain
      rejects = Rejects.new(block_factory.blockchain)
      rejects.record(chain).should be_nil
    end
  end

  describe "record_reject" do
    it "should record a rejected transaction with exception message" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(2).chain
        transaction_id = chain.last.transactions.last.id
        rejects = Rejects.new(block_factory.blockchain)
        rejects.record_reject(transaction_id, Exception.new("oops"))
        rejects.@rejects.should eq({transaction_id => "oops"})
      end
    end
    it "should record a rejected transaction with default exception message" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(2).chain
        transaction_id = chain.last.transactions.last.id
        rejects = Rejects.new(block_factory.blockchain)
        rejects.record_reject(transaction_id, Exception.new)
        rejects.@rejects.should eq({transaction_id => "unknown"})
      end
    end
  end
  it "should perform #clear" do
    with_factory do |block_factory, _|
      chain = block_factory.add_slow_blocks(2).chain
      rejects = Rejects.new(block_factory.blockchain)
      rejects.record_reject(chain.last.transactions.last.id, Exception.new)
      rejects.clear
      rejects.@rejects.size.should eq(0)
    end
  end

end
