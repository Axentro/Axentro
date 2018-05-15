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

require "../src/core"

include ::Sushi::Core
include ::Sushi::Common::Denomination

def create_block(index : Int64) : Block
  Block.new(index, [] of Transaction, 0_u64, "")
end

t_amount = 0_i64
c_amount = 0_i64

i = 0_i64

loop do
  c_amount = create_block(i).coinbase_amount

  break if c_amount == 0

  t_amount += c_amount
  i += 1

  puts "at #{i} (current amount: #{c_amount}, total amount: #{scale_decimal(t_amount)} [SUSHI])\r" if i % 1000000 == 0
end

puts ""
puts "Total amount : #{scale_decimal(t_amount)} [SUSHI]"
puts "Last index   : #{i}"
