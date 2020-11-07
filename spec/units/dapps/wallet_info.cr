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

describe WalletInfo do
  describe "default non implemented methods" do
    it "should perform #setup" do
      with_factory do |block_factory, _|
        transaction_creator = WalletInfo.new(block_factory.add_slow_block.blockchain)
        transaction_creator.setup.should be_nil
      end
    end
    it "should perform #transaction_actions" do
      with_factory do |block_factory, _|
        transaction_creator = WalletInfo.new(block_factory.add_slow_block.blockchain)
        transaction_creator.transaction_actions.size.should eq(0)
      end
    end
    it "should perform #transaction_related?" do
      with_factory do |block_factory, _|
        transaction_creator = WalletInfo.new(block_factory.add_slow_block.blockchain)
        transaction_creator.transaction_related?("action").should be_false
      end
    end
    it "should perform #valid_transaction?" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(2).chain
        transaction_creator = WalletInfo.new(block_factory.blockchain)
        result = transaction_creator.valid_transactions?(chain.last.transactions)
        result.failed.size.should eq(0)
        result.passed.size.should eq(1)
      end
    end
    it "should perform #record" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(2).chain
        transaction_creator = WalletInfo.new(block_factory.blockchain)
        transaction_creator.record(chain).should be_nil
      end
    end
    it "should perform #clear" do
      with_factory do |block_factory, _|
        transaction_creator = WalletInfo.new(block_factory.add_slow_blocks(2).blockchain)
        transaction_creator.clear.should be_nil
      end
    end
  end

  describe "#wallet_info" do
    it "should return the wallet info for the specified address" do
      with_factory do |block_factory, transaction_factory|
        block_factory.add_slow_blocks(2).add_slow_block(
          [transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64),
           transaction_factory.make_send(99900000000),
          ]).add_slow_blocks(2)

        payload = {call: "wallet_info", address: transaction_factory.sender_wallet.address}.to_json
        json = JSON.parse(payload)

        with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
          wi = WalletInfoResponse.from_json(result)
          wi.address.should eq(transaction_factory.sender_wallet.address)
          wi.readable.should eq(["domain1.ax"])
        end
      end
    end
  end
end
