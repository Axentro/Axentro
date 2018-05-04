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

module ::Sushi::Core::Logger
  def debug(msg : String)
    return if ENV.has_key?("SC_UNIT") || ENV.has_key?("SC_INTEGRATION") || ENV.has_key?("SC_E2E")
    return unless ENV.has_key?("SC_DEBUG")
    log_out("Debug", msg, :dark_gray)
  end

  def info(msg : String)
    return if ENV.has_key?("SC_UNIT") || ENV.has_key?("SC_INTEGRATION") || ENV.has_key?("SC_E2E")
    log_out("Info", msg, :light_green)
  end

  def warning(msg : String)
    return if ENV.has_key?("SC_UNIT") || ENV.has_key?("SC_INTEGRATION")
    log_out("Warning", msg, :yellow)
  end

  def error(msg : String)
    log_out("Error", msg, :red)
  end

  def progress(msg : String)
    return if ENV.has_key?("SC_UNIT") || ENV.has_key?("SC_E2E")
    print msg
  end

  private def log_out(t : String, msg : String, color : Symbol)
    puts "[ #{ftime} -- #{tag(t, color)} ] #{msg}"
  end

  private def tag(t : String, color : Symbol) : String
    ("%7s" % t).colorize.fore(color).to_s
  end

  private def ftime : String
    Time.now.to_s("%Y-%m-%d %H:%M:%S")
  end
end
