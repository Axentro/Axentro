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
require "benchmark"

include Axentro::Core
include Hashes
include Units::Utils
include Axentro::Core::DApps::BuildIn
include Axentro::Core::Controllers
include Axentro::Core::Block

describe Blockchain do
  describe "setup" do
    it "should recover from database error when trying to insert a block that already exists" do
      with_factory do |block_factory|
        database = block_factory.blockchain.database
        block = SlowBlock.new(0_i64, [] of Transaction, "0", "genesis", 0_i64, 3_i32, "123")
        # no error should be thrown here
        (1..2).to_a.each do
          database.push_block(block)
        end
      end
    end
    it "should recover from database error when trying to insert a fast transaction that already exists" do
      with_factory do |_, transaction_factory|
        transaction = transaction_factory.make_send(200000000_i64)
        # no error should be thrown here
        (1..2).to_a.each do
          FastTransactionPool.add(transaction)
        end
      end
    end
  end
end
