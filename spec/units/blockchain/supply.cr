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

include Units::Utils
include Sushi::Core
include Sushi::Core::TransactionModels
include ::Sushi::Common::Denomination
include Hashes

describe Blockchain do
  it "should calculate the total supply" do
    with_factory do |block_factory, _|
      t_amount = 0_i64
      c_amount = 0_i64
      i = 0_i64

      loop do
        c_amount = block_factory.blockchain.coinbase_amount(i, [] of Transaction)
        break if c_amount == 0

        t_amount += c_amount
        i += 1
        # puts "at #{i} (current amount: #{c_amount}, total amount: #{scale_decimal(t_amount)} [SUSHI])\r" if i % 1000000 == 0
      end

      # puts ""
      # puts "Total amount : #{scale_decimal(t_amount)} [SUSHI]"
      # puts "Last index   : #{i}"

      i.should eq(50462651_i64)                              # last index
      scale_decimal(t_amount).should eq("20000000.00004112") # total supply
    end
  end
  STDERR.puts "< Total Supply"
end
