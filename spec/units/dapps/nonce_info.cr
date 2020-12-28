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

include Axentro::Core
include Units::Utils
include Axentro::Core::DApps::BuildIn
include Axentro::Core::Controllers

describe NonceInfo do
  describe "default non implemented methods" do
    it "should perform #setup" do
      with_factory do |block_factory, _|
        fees = NonceInfo.new(block_factory.add_slow_block.blockchain)
        fees.setup.should be_nil
      end
    end
    it "should perform #transaction_actions" do
      with_factory do |block_factory, _|
        fees = NonceInfo.new(block_factory.add_slow_block.blockchain)
        fees.transaction_actions.size.should eq(0)
      end
    end
    it "should perform #transaction_related?" do
      with_factory do |block_factory, _|
        fees = NonceInfo.new(block_factory.add_slow_block.blockchain)
        fees.transaction_related?("action").should be_false
      end
    end
    it "should perform #valid_transaction?" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(2).chain
        fees = NonceInfo.new(block_factory.blockchain)
        result = fees.valid_transactions?(chain.last.transactions)
        result.failed.size.should eq(0)
        result.passed.size.should eq(1)
      end
    end
    it "should perform #record" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(2).chain
        fees = NonceInfo.new(block_factory.blockchain)
        fees.record(chain).should be_nil
      end
    end
    it "should perform #clear" do
      with_factory do |block_factory, _|
        fees = NonceInfo.new(block_factory.add_slow_blocks(2).blockchain)
        fees.clear.should be_nil
      end
    end
  end
end
