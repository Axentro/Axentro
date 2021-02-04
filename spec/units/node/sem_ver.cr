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

describe SemVer do
  it "should return the semver parts" do
    semver = SemVer.new("1.2.3")
    semver.major_version.should eq(1)
    semver.minor_version.should eq(2)
    semver.patch_version.should eq(3)
  end

  it "should validate the semver" do
    assert_valid_format("1x.2.3")
    assert_valid_format("invalid")
    assert_valid_format("1x.2.3.4")
    assert_valid_format("1.2.3.4")
  end

  describe "version equality" do
    it "when breaking change" do
      (SemVer.new("3.0.0").major_version > SemVer.new("2.0.0").major_version).should eq(true)
    end
  end
end

def assert_valid_format(version)
  expect_raises(Exception, "Semantic versioning validation error: Invalid sementic version format for supplied version: #{version} - it should be in the format e.g. 1.0.1") do
    SemVer.new(version)
  end
end
