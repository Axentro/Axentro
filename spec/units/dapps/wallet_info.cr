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
        transaction_creator.valid_transaction?(chain.last.transactions.first, chain.last.transactions).should be_true
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
            [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64),
             transaction_factory.make_buy_domain_from_platform("domain2.sc", 0_i64),
            ]).add_slow_blocks(2)

        payload = {call: "wallet_info", address: transaction_factory.sender_wallet.address}.to_json
        json = JSON.parse(payload)

        with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            pp result
        #   result.should eq(block_factory.blockchain.chain.reverse.to_json)
        end
      end
    end
  end
end

#   describe "#define_rpc?" do
#     describe "#blockchain_size" do
#       it "should return the blockchain size for the current node" do
#         with_factory do |block_factory, _|
#           block_factory.add_slow_blocks(10)
#           payload = {call: "blockchain_size"}.to_json
#           json = JSON.parse(payload)

#           with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
#             result.should eq(%{{"totals":{"total_size":11,"total_fast":0,"total_slow":11},"block_height":{"slow":20,"fast":-1}}})
#           end
#         end
#       end
#     end

#   end

# end
