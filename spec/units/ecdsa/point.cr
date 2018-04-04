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

include Sushi::Core
include Sushi::Core::ECDSA

describe Point do
  it "should create a point when calling #initialize" do
    secp256k1 = ECDSA::Secp256k1.new
    key_pair = secp256k1.create_key_pair
    group = secp256k1.unsafe_as(Group)
    point = Point.new(group, key_pair[:public_key].x, key_pair[:public_key].y, false)

    point.infinity?.should be_false
    point.x.should eq(key_pair[:public_key].x)
    point.y.should eq(key_pair[:public_key].y)
  end

  it "should return group_p when calling #mod" do
    group = ECDSA::Secp256k1.new.unsafe_as(Group)
    point = Point.new(group, BigInt.new(0), BigInt.new(0), false)
    point.mod.should eq(group._p)
  end

  it "should return group_a when calling #_a" do
    group = ECDSA::Secp256k1.new.unsafe_as(Group)
    point = Point.new(group, BigInt.new(0), BigInt.new(0), false)
    point._a.should eq(group._a)
  end

  it "should return group_b when calling #_b" do
    group = ECDSA::Secp256k1.new.unsafe_as(Group)
    point = Point.new(group, BigInt.new(0), BigInt.new(0), false)
    point._b.should eq(group._b)
  end

  describe "#+" do
    it "should return point2 (other) if point1 (self) is infinity" do
      group = ECDSA::Secp256k1.new.unsafe_as(Group)
      point1 = Point.new(group, BigInt.new(0), BigInt.new(0), true)
      point2 = Point.new(group, BigInt.new(123456789), BigInt.new(987654321), false)
      (point1 + point2).should eq(point2)
    end
    it "should return point1 (self) if point2 (other) is infinity" do
      group = ECDSA::Secp256k1.new.unsafe_as(Group)
      point1 = Point.new(group, BigInt.new(123456789), BigInt.new(987654321), false)
      point2 = Point.new(group, BigInt.new(0), BigInt.new(0), true)
      (point1 + point2).should eq(point1)
    end
    it "should return a point if neither are infinity" do
      group = ECDSA::Secp256k1.new.unsafe_as(Group)
      point1 = Point.new(group, BigInt.new(123456789), BigInt.new(987654321), false)
      point2 = Point.new(group, BigInt.new(0), BigInt.new(0), false)

      point = (point1 + point2)
      point.infinity?.should be_false
      point.x.should eq(BigInt.new("38717823571956855866063416460371802231574262020959307453724617570910485689638"))
      point.y.should eq(BigInt.new("46246057464311081086891639547982163200274133780717245683875867738266119247429"))
    end
  end

  describe "#double" do
    it "should return point (self) if point is infinity" do
      point = Point.new(ECDSA::Secp256k1.new.unsafe_as(Group), BigInt.new(0), BigInt.new(0), true)
      point.double.should eq(point)
    end
    it "should return a double when point is not infinity" do
      point = Point.new(ECDSA::Secp256k1.new.unsafe_as(Group), BigInt.new(1), BigInt.new(2), false)
      double = point.double
      double.infinity?.should be_false
      double.x.should eq(BigInt.new("65133050195990359925758679067386948167464366374422817272194891004448719502809"))
      double.y.should eq(BigInt.new("66942301590323425479251975708147696727671709884823451085311415754572295044555"))
    end
  end

  describe "#*" do
    it "should multiply by supplied bigInt" do
      point = Point.new(ECDSA::Secp256k1.new.unsafe_as(Group), BigInt.new(1), BigInt.new(2), false)
      res = point * BigInt.new(2)
      res.infinity?.should be_false
      res.x.should eq(BigInt.new("65133050195990359925758679067386948167464366374422817272194891004448719502809"))
      res.y.should eq(BigInt.new("66942301590323425479251975708147696727671709884823451085311415754572295044555"))
    end

    it "should return infinity if supplied bigInt is less than 0" do
      point = Point.new(ECDSA::Secp256k1.new.unsafe_as(Group), BigInt.new(1), BigInt.new(2), false)
      res = point * BigInt.new(-1)
      res.infinity?.should be_true
      res.x.should eq(BigInt.new(0))
      res.y.should eq(BigInt.new(0))
    end
  end

  describe "#is_on?" do
    it "should return false if is not on" do
      point = Point.new(ECDSA::Secp256k1.new.unsafe_as(Group), BigInt.new(1), BigInt.new(2), false)
      point.is_on?.should be_false
    end
  end

  describe "#infinity?" do
    it "should return true when point is infinity" do
      point = Point.new(ECDSA::Secp256k1.new.unsafe_as(Group), BigInt.new(1), BigInt.new(2), false)
      point.infinity?.should be_false
    end
    it "should return false when point is not infinity" do
      point = Point.new(ECDSA::Secp256k1.new.unsafe_as(Group), BigInt.new(0), BigInt.new(0), true)
      point.infinity?.should be_true
    end
  end
  STDERR.puts "< ECDSA::Point"
end
