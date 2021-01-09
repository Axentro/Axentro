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
include Hashes
include Units::Utils
include Axentro::Core::DApps::BuildIn
include Axentro::Core::Controllers
include Axentro::Core::Block

describe "slow block ids for validation should include genesis index plus specified percentage of rest of the slow chain - backed off by latest 10" do
  it "when (chain - latest 10) is less than 10" do
    security_percentage = 20_i64
    max_slow_index = 20_i64

    plan = ChainIntegrity.new(max_slow_index, 0_i64, security_percentage).get_validation_block_ids_for_slow
    assert_integrity_slow_plan(plan, max_slow_index, security_percentage, 1)
  end

  it "when (chain - latest 10) is exactly 10" do
    security_percentage = 20_i64
    max_slow_index = 30_i64

    plan = ChainIntegrity.new(max_slow_index, 0_i64, security_percentage).get_validation_block_ids_for_slow
    assert_integrity_slow_plan(plan, max_slow_index, security_percentage, 1)
  end

  it "when (chain - latest 10) is greater than 10" do
    security_percentage = 20_i64
    max_slow_index = 40_i64

    plan = ChainIntegrity.new(max_slow_index, 0_i64, security_percentage).get_validation_block_ids_for_slow
    assert_integrity_slow_plan(plan, max_slow_index, security_percentage, 3)
  end

  it "when (chain - latest 10) is much greater than 10" do
    security_percentage = 20_i64
    max_slow_index = 200_i64

    plan = ChainIntegrity.new(max_slow_index, 0_i64, security_percentage).get_validation_block_ids_for_slow
    assert_integrity_slow_plan(plan, max_slow_index, security_percentage, 19)
  end

  it "with 0 percent" do
    security_percentage = 0_i64
    max_slow_index = 200_i64

    plan = ChainIntegrity.new(max_slow_index, 0_i64, security_percentage).get_validation_block_ids_for_slow
    assert_integrity_slow_plan(plan, max_slow_index, security_percentage, 1)
  end

  it "with 50 percent" do
    security_percentage = 50_i64
    max_slow_index = 200_i64

    plan = ChainIntegrity.new(max_slow_index, 0_i64, security_percentage).get_validation_block_ids_for_slow
    assert_integrity_slow_plan(plan, max_slow_index, security_percentage, 46)
  end

  it "with 100 percent" do
    security_percentage = 100_i64
    max_slow_index = 200_i64

    plan = ChainIntegrity.new(max_slow_index, 0_i64, security_percentage).get_validation_block_ids_for_slow
    assert_integrity_slow_plan(plan, max_slow_index, security_percentage, 91)
  end
end

describe "fast block ids for validation should be specified percentage of the fast chain - backed off by latest 10" do
  it "when (chain - latest 10) is less than 10" do
    security_percentage = 20_i64
    max_fast_index = 19_i64

    plan = ChainIntegrity.new(0_i64, max_fast_index, security_percentage).get_validation_block_ids_for_fast
    assert_integrity_fast_plan(plan, max_fast_index, security_percentage, 0)
  end

  it "when (chain - latest 10) is exactly 10" do
    security_percentage = 20_i64
    max_fast_index = 31_i64

    plan = ChainIntegrity.new(0_i64, max_fast_index, security_percentage).get_validation_block_ids_for_fast
    assert_integrity_fast_plan(plan, max_fast_index, security_percentage, 1)
  end

  it "when (chain - latest 10) is greater than 10" do
    security_percentage = 20_i64
    max_fast_index = 41_i64

    plan = ChainIntegrity.new(0_i64, max_fast_index, security_percentage).get_validation_block_ids_for_fast
    assert_integrity_fast_plan(plan, max_fast_index, security_percentage, 3)
  end

  it "when (chain - latest 10) is much greater than 10" do
    security_percentage = 20_i64
    max_fast_index = 201_i64

    plan = ChainIntegrity.new(0_i64, max_fast_index, security_percentage).get_validation_block_ids_for_fast
    assert_integrity_fast_plan(plan, max_fast_index, security_percentage, 19)
  end

  it "with 0 percent" do
    security_percentage = 0_i64
    max_fast_index = 201_i64

    plan = ChainIntegrity.new(0_i64, max_fast_index, security_percentage).get_validation_block_ids_for_fast
    assert_integrity_fast_plan(plan, max_fast_index, security_percentage, 0)
  end

  it "with 50 percent" do
    security_percentage = 50_i64
    max_fast_index = 201_i64

    plan = ChainIntegrity.new(0_i64, max_fast_index, security_percentage).get_validation_block_ids_for_fast
    assert_integrity_fast_plan(plan, max_fast_index, security_percentage, 46)
  end

  it "with 100 percent" do
    security_percentage = 100_i64
    max_fast_index = 201_i64

    plan = ChainIntegrity.new(0_i64, max_fast_index, security_percentage).get_validation_block_ids_for_fast
    assert_integrity_fast_plan(plan, max_fast_index, security_percentage, 91)
  end
end

describe "mixed block ids for validation should be (specified percentage of slow chain - backed off by latest 10) + (specified percentage of fast chain - backed off by latest 10)" do
  it "when (chain - latest 10) is less than 10" do
    security_percentage = 20_i64
    max_slow_index = 20_i64
    max_fast_index = 19_i64

    plan = ChainIntegrity.new(max_slow_index, max_fast_index, security_percentage).get_validation_block_ids
    assert_integrity_mixed_plan(plan, max_slow_index, max_fast_index, security_percentage, 0)
  end

  it "when (chain - latest 10) is exactly 10" do
    security_percentage = 20_i64
    max_slow_index = 30_i64
    max_fast_index = 31_i64

    plan = ChainIntegrity.new(max_slow_index, max_fast_index, security_percentage).get_validation_block_ids
    assert_integrity_mixed_plan(plan, max_slow_index, max_fast_index, security_percentage, 1)
  end

  it "when (chain - latest 10) is greater than 10" do
    security_percentage = 20_i64
    max_slow_index = 40_i64
    max_fast_index = 41_i64

    plan = ChainIntegrity.new(max_slow_index, max_fast_index, security_percentage).get_validation_block_ids
    assert_integrity_mixed_plan(plan, max_slow_index, max_fast_index, security_percentage, 6)
  end

  it "when (chain - latest 10) is much greater than 10" do
    security_percentage = 20_i64
    max_slow_index = 200_i64
    max_fast_index = 201_i64

    plan = ChainIntegrity.new(max_slow_index, max_fast_index, security_percentage).get_validation_block_ids
    assert_integrity_mixed_plan(plan, max_slow_index, max_fast_index, security_percentage, 38)
  end

  it "with 0 percent" do
    security_percentage = 0_i64
    max_slow_index = 200_i64
    max_fast_index = 201_i64

    plan = ChainIntegrity.new(max_slow_index, max_fast_index, security_percentage).get_validation_block_ids
    assert_integrity_mixed_plan(plan, max_slow_index, max_fast_index, security_percentage, 1)
  end

  it "with 50 percent" do
    security_percentage = 50_i64
    max_slow_index = 200_i64
    max_fast_index = 201_i64

    plan = ChainIntegrity.new(max_slow_index, max_fast_index, security_percentage).get_validation_block_ids
    assert_integrity_mixed_plan(plan, max_slow_index, max_fast_index, security_percentage, 92)
  end

  it "with 100 percent" do
    security_percentage = 100_i64
    max_slow_index = 200_i64
    max_fast_index = 201_i64

    plan = ChainIntegrity.new(max_slow_index, max_fast_index, security_percentage).get_validation_block_ids
    assert_integrity_mixed_plan(plan, max_slow_index, max_fast_index, security_percentage, 180)
  end
end

private def assert_integrity_slow_plan(plan, max_slow_index, security_percentage, expected_plan_size)
  plan.should contain(0_i64)
  plan.size.should be >= expected_plan_size

  rejections = (0_i64..max_slow_index).reject(&.odd?).last(10)
  rejections.each do |r|
    plan.should_not contain(r)
  end
end

private def assert_integrity_fast_plan(plan, max_fast_index, security_percentage, expected_plan_size)
  plan.should_not contain(0_i64)
  plan.size.should be >= expected_plan_size

  rejections = (0_i64..max_fast_index).reject(&.even?).last(10)
  rejections.each do |r|
    plan.should_not contain(r)
  end
end

private def assert_integrity_mixed_plan(plan, max_slow_index, max_fast_index, security_percentage, expected_plan_size)
  plan.should contain(0_i64)

  plan.size.should be >= expected_plan_size

  rejections = (0_i64..max_slow_index).reject(&.odd?).last(10) + (0_i64..max_fast_index).reject(&.even?).last(10)
  rejections.each do |r|
    plan.should_not contain(r)
  end
end
