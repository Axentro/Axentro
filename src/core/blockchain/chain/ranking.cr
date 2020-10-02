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

module ::Axentro::Core
  struct Ranking
    def self.chain(chain)
      chain.select(&.is_slow_block?).map { |block| block.address }.first(1440)
    end

    def self.rank(address, chain) : Int32
      chain.tally[address]? || 0
    end
  end
end
