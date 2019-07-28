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
require "benchmark"

include Sushi::Core
include Hashes
include Units::Utils
include Sushi::Core::DApps::BuildIn
include Sushi::Core::Controllers

describe Blockchain do
  it "align transactions" do
    with_factory do |block_factory, transaction_factory|
      transaction_total = 2000
      transactions = (1..transaction_total).to_a.map{|n| transaction_factory.make_send(n.to_i64) }

      block_factory.add_block(transactions)
      block_factory.blockchain.embedded_transactions.size.should eq(transaction_total)
      coinbase_transaction = block_factory.blockchain.chain.last.transactions.first

      puts Benchmark.measure {
        block_factory.blockchain.align_transactions(coinbase_transaction, 1)
      }

    end
  end
end

# describe UTXO do
#   it "should return utxo for transactions with mixed tokens" do
#     with_factory do |block_factory, transaction_factory|
#       transaction1 = transaction_factory.make_send(100_i64, "KINGS")
#       transaction2 = transaction_factory.make_send(200_i64)
#       chain = block_factory.add_block.chain
#       utxo = UTXO.new(block_factory.blockchain)
#       utxo.record(chain)
#       # expected = {"KINGS"       => {"#{transaction_factory.sender_wallet.address}" => -100_i64, "#{transaction_factory.recipient_wallet.address}" => 100_i64},
#       #             TOKEN_DEFAULT => {"#{transaction_factory.sender_wallet.address}" => -20200_i64, "#{transaction_factory.recipient_wallet.address}" => 200_i64}}
#
#       expected1 =
#         TokenQuantity.new(
#           "KINGS",
#           [AddressQuantity.new(transaction_factory.sender_wallet.address,-100_i64),
#           AddressQuantity.new(transaction_factory.recipient_wallet.address,100_i64)]
#         )
#
#         expected2 = TokenQuantity.new(
#           TOKEN_DEFAULT,
#           [AddressQuantity.new(transaction_factory.sender_wallet.address,-20200_i64),
#           AddressQuantity.new(transaction_factory.recipient_wallet.address,200_i64)]
#         )
#
#
#       # utxo.calculate_for_transactions([transaction1, transaction2]).should eq(expected)
#       result = utxo.calculate_for_transactions([transaction1, transaction2])
#       result.first.should eq(expected1)
#       result.last.should eq(expected2)
#     end
#   end
# end
