# Copyright © 2017-2018 The Axentro Core developers
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

module ::Axentro::Interface::Logger
  def puts_info(_msg : String?)
    return unless msg = _msg
    puts light_gray(msg)
  end

  def puts_success(_msg : String?)
    return unless msg = _msg
    puts light_green(msg)
  end

  def puts_error(_msg : String?)
    return unless msg = _msg

    if G.op.__json
      puts ({
        error:   true,
        message: _msg,
      }.to_json)
    else
      puts red(msg)
    end

    exit -1
  end

  def puts_warning(_msg : String?)
    return unless msg = _msg
    puts yellow(msg)
  end

  def debug(msg : String)
    log_out("Debug", msg, :light_gray)
  end

  def error(msg : String)
    log_out("Error", msg, :red)
  end

  def warning(msg : String)
    log_out("Warning", msg, :yellow)
  end

  def info(msg : String)
    log_out("Info", msg, :light_green)
  end

  private def log_out(t : String, msg : String, color : Symbol)
    puts "[ #{ftime} -- #{tag(t, color)} ] #{msg}"
  end

  private def tag(t : String, color : Symbol) : String
    ("%7s" % t).colorize.fore(color).to_s
  end

  private def ftime : String
    Time.utc.to_s("%Y-%m-%d %H:%M:%S")
  end

  include Common::Color
end
