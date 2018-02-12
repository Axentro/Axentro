module ::E2E::Utils::Miner
  def sushim(args) : String
    _args = args
      .map { |arg| arg.to_s }
      .join(" ")

    bin = File.expand_path("../../../../bin/sushim", __FILE__)

    "#{bin} #{_args}"
  end

  def mining(port : Int32, num : Int32)
    STDERR.puts "#{light_blue("launch miner")}: port(#{port}) num(#{num})"

    args = ["-w", "wallets/testnet-#{num}.json", "--password=passwordpassword", "-n", "http://127.0.0.1:#{port}", "--testnet"]

    bin = sushim(args)

    spawn do
      system("#{bin} &> #{log_path(num, true)}")
    end
  end
end
