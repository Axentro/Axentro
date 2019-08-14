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

class Spec::TAPFormatter < Spec::Formatter
  @counter = 0

  def report(result)
    case result.kind
    when :success
      @io << "ok"
    when :fail, :error
      @io << "not ok"
    when :pending
      @io << "ok"
    when :ignored
      @io << "ok"
    end

    @counter += 1

    @io << ' ' << @counter << " -"
    if result.kind == :ignored
      @io << " # IGNORED"
    end
    @io << ' ' << result.description

    @io.puts
  end

  def finish
    @io << "1.." << @counter
    @io.puts
  end
end
