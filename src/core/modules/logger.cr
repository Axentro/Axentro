module ::Sushi::Core::Logger
  def debug(msg : String)
    return if ENV.has_key?("UNIT") || ENV.has_key?("E2E")
    log_out("Debug", msg, :light_gray)
  end

  def info(msg : String)
    return if ENV.has_key?("UNIT") || ENV.has_key?("E2E")
    log_out("Info", msg, :light_green)
  end

  def warning(msg : String)
    return if ENV.has_key?("UNIT") || ENV.has_key?("E2E")
    log_out("Warning", msg, :yellow)
  end

  def error(msg : String)
    log_out("Error", msg, :red)
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
