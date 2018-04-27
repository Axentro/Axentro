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

require "../../src/common"
require "../../src/core"
require "./runner"
require "option_parser"

include ::Sushi::Common::Color

class SushiChainE2E
  @mode : String = "all_public"
  @num_nodes : Int32 = 5
  @num_miners : Int32 = 5
  @time : Int32 = 540

  def initialize
    ENV["E2E"] = "true"
  end

  def parse_option!
    OptionParser.parse! do |parser|
      parser.banner = "Usage: e2e [options]"
      parser.on("--mode=MODE", "E2E test mode (on of [all_public, all_private, one_private])") do |mode|
        if mode != "all_public" && mode != "all_private" && mode != "one_private"
          puts "the mode is one of [all_public, all_private, one_private]"
          exit -1
        end

        @mode = mode
      end

      parser.on("--num_nodes=NUM", "# of nodes (default is 5)") do |num|
        @num_nodes = num.to_i
      end

      parser.on("--num_miners=NUM", "# of miners (default is 5)") do |num|
        @num_miners = num.to_i
      end

      parser.on("--time=TIME", "execution time in sec (default is 540 )") do |time|
        @time = time.to_i
      end

      parser.on("--help", "show this help") do
        puts parser.to_s
        exit 0
      end
    end
  end

  def run!
    runner_mode = case @mode
                  when "all_public"
                    E2E::ALL_PUBLIC
                  when "all_private"
                    E2E::ALL_PRIVATE
                  when "one_private"
                    E2E::ONE_PRIVATE
                  else
                    E2E::ALL_PUBLIC
                  end

    raise "invalid value of arg --num_nodes" if @num_nodes < 0
    raise "invalid value of arg --num_miners" if @num_miners < 0

    runner = ::E2E::Runner.new(runner_mode, @num_nodes, @num_miners, @time)
    runner.run!
  end
end

e2e = SushiChainE2E.new
e2e.parse_option!
e2e.run!
