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

require "../../src/common"
require "../../src/core"
require "./runner"

include ::Sushi::Common::Color

mode = if _mode_arg = ARGV.find { |arg| arg.starts_with?("--mode=") }
         _mode = _mode_arg.split("=")[1]

         case _mode
         when "all_public"
           E2E::ALL_PUBLIC
         when "all_private"
           E2E::ALL_PRIVATE
         when "one_private"
           E2E::ONE_PRIVATE
         else
           E2E::ALL_PUBLIC
         end
       else
         E2E::ALL_PUBLIC
       end

runner = ::E2E::Runner.new(mode)
runner.run!
