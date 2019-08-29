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
      transaction_total = 10
      transactions = (1..transaction_total).to_a.map{|n| transaction_factory.make_send(n.to_i64) }

      block_factory.add_slow_block(transactions)
      block_factory.blockchain.embedded_slow_transactions.size.should eq(transaction_total)
      coinbase_transaction = block_factory.blockchain.chain.last.transactions.first

      puts Benchmark.measure {
        block_factory.blockchain.align_slow_transactions(coinbase_transaction, 1)
      }
    end
  end

  it "clean transactions" do
    with_factory do |block_factory, transaction_factory|
      transaction_total = 10
      transactions = (1..transaction_total).to_a.map{|n| transaction_factory.make_send(n.to_i64) }

      block_factory.add_slow_block(transactions)
      block_factory.blockchain.pending_slow_transactions.size.should eq(transaction_total)

      puts Benchmark.measure {
        block_factory.blockchain.clean_slow_transactions
      }
    end
  end
end
