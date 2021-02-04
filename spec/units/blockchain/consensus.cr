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
require "./../../../src/cli/modules/logger"

include Axentro::Core
include Axentro::Core::Consensus
include Axentro::Interface::Logger
include Units::Utils

describe Consensus do
  describe "calculate_pow_difficulty" do
    it "should return a valid difficulty value" do
      ENV.delete("AX_SET_DIFFICULTY")
      hash = "e33598878258c85c60c5c29a41ad756cb69ecd315154695970c375a792eb8f4e"
      nonce = "17186779519462547558"
      calculate_pow_difficulty(hash, nonce, 13).should eq(13)
    end
  end

  describe "is_nonce_valid?" do
    it "when valid" do
      ENV.delete("AX_SET_DIFFICULTY")
      hash = "e33598878258c85c60c5c29a41ad756cb69ecd315154695970c375a792eb8f4e"
      nonce = "17186779519462547558"
      is_nonce_valid?(hash, nonce, 13).should eq(true)
    end
    it "when invalid" do
      ENV.delete("AX_SET_DIFFICULTY")
      hash = "e33598878258c85c60c5c29a41ad756cb69ecd315154695970c375a792eb8f4e"
      nonce = "17186779519462547559"
      is_nonce_valid?(hash, nonce, 13).should eq(false)
    end
  end
end
