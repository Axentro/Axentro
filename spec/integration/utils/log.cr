module ::Integration::Utils::Log
  def log_path(num : Int32, is_miner : Bool = false) : String
    log_name = is_miner ? "#{num}_miner.log" : "#{num}.log"
    File.expand_path("../../logs/#{log_name}", __FILE__)
  end
end
