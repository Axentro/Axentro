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

module ::Sushi::Core
  struct Ranking
    property rank : Int32
    property percentage : Int32
    property address : String

    def initialize(@rank : Int32, @percentage : Int32, @address : String); end

    def self.as_percentage(percent_of : Int32, total : Int32) : Int32
      ((percent_of.to_f64 / total.to_f64) * 100).round.to_i32
    end

    def self.chain(chain)
      chain.select(&.is_slow_block?).map{ |block| block.address }
    end

    def self.rank(address, chain) : Int32
      tallied_rankings = chain.tally
      total = tallied_rankings.values.sum
      ranks = tallied_rankings.map { |k, v| Ranking.new(v, as_percentage(v, total), k) }
        .select { |rank| rank.percentage > 25 }

      rank = ranks.find { |rank| rank.address == address }
      rank ? rank.rank : 0
    end
  end
end
