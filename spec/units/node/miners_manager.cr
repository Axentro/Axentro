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

include Axentro::Core
include Units::Utils
include Axentro::Core::NodeComponents

ONE_SECOND = 1000

describe MinersManager do
  it "should include in ban list if duration between join and remove is less than 10 seconds for 10 times" do
    now = __timestamp
    miner_mortality = LRUCache(String, Array(MinerMortality)).new(max_size: 10_000)

    (1..11).to_a.each do |_|
      join_and_remove(miner_mortality, now, ONE_SECOND)
      now += ONE_SECOND
    end

    MinersManager.ban_list(miner_mortality.items).should eq(Set{"1"})
  end

  it "should not include in ban list if duration between join and remove is greater than 10 seconds for 10 times" do
    now = __timestamp
    miner_mortality = LRUCache(String, Array(MinerMortality)).new(max_size: 10_000)

    # add 9 that are less than boundary
    (1..9).to_a.each do |_|
      join_and_remove(miner_mortality, now, ONE_SECOND * 11)
      now += ONE_SECOND
    end

    # add 10 that are greater then boundary
    (1..10).to_a.each do |_|
      join_and_remove(miner_mortality, now, ONE_SECOND * 11)
    end

    # should not be in ban list because only 9 happened less than boundary
    MinersManager.ban_list(miner_mortality.items).should be_empty
  end
end

def join_and_remove(miner_mortality, now, spacing)
  mortalities = miner_mortality.get("1") || [] of MinerMortality
  mortalities << MinerMortality.new("joined", now)
  mortalities << MinerMortality.new("remove", now + spacing)
  miner_mortality.set("1", mortalities, Time.utc + 10.minutes)
end
