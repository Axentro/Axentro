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

total_amount = 0_i64
current_index = 0_u64

loop do
  served_amount = ::Sushi::Core::Blockchain.served_amount(current_index)
  break if served_amount == 0

  total_amount += served_amount
  current_index += 1
end

puts "total amount: #{total_amount}"
