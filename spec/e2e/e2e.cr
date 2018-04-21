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

ENV["E2E"] = "true"

require "../spec_helper"
require "./runner"

include ::Sushi::Common::Color

num_nodes = ENV.has_key?("NUM_NODES") ? ENV["NUM_NODES"].to_i : 3
num_miners = ENV.has_key?("NUM_MINERS") ? ENV["NUM_MINERS"].to_i : 3

runner = ::E2E::Runner.new(num_nodes, num_miners)
runner.run!
