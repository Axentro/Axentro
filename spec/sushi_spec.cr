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

require "./spec_helper"

include ::Sushi::Common::Color

ENV["SC_UNIT"] = "true"

puts light_cyan("> unit tests")
require "./units/units"

ENV.delete("SC_UNIT")

ENV["SC_INTEGRATION"] = "true"

puts ""
puts light_cyan("> integration tests")
require "./integration/integration"

ENV.delete("SC_INTEGRATION")

ENV["SC_FUNCTIONAL"] = "true"

puts ""
puts light_cyan("> spinach functional tests")
require "./functional/runner"

ENV.delete("SC_FUNCTIONAL")
