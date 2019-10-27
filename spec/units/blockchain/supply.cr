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

include Units::Utils
include Sushi::Core
include Sushi::Core::TransactionModels
include ::Sushi::Common::Denomination
include Hashes

describe Blockchain do
  pending "should calculate the total supply" do
    with_factory do |block_factory, _|
      total_supply = (0_i64..8000000_i64).select(&.even?).reduce(0_i64) { |acc, i| block_factory.blockchain.coinbase_slow_amount(i, [] of Transaction) + acc }
      scale_decimal(total_supply).should eq("20146527.97498925")
    end
  end
  STDERR.puts "< Total Supply"
end
