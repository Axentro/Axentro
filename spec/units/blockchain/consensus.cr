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
    # TODO: this test is probably erroneously passing since the change to the 'valid' methods
    it "should return a valid difficulty value" do
      ENV.delete("AX_SET_DIFFICULTY")
      nonce = "2978736204850283095"
      calculate_pow_difficulty("block_hash", nonce, 2).should be < 3
    end
  end
end
