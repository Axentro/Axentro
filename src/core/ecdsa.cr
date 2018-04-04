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

module ::Sushi::Core::ECDSA
  def mod_inv(a : BigInt, mod : BigInt)
    lim, him = BigInt.new(1), BigInt.new(0)
    low, high = a % mod, mod

    while low > 1
      ratio = high / low
      nm = him - lim * ratio
      new = high - low * ratio
      him = lim
      high = low
      lim = nm
      low = new
    end

    lim % mod
  end

  include Hashes
end

require "./ecdsa/*"
