module ::E2E::Utils::Node

  def sushid(args) : String
    _args = args
            .map { |arg| arg.to_s }
            .join(" ")

    bin = File.expand_path("../../../../bin/sushid", __FILE__)

    "#{bin} #{_args}"
  end

  def node(port : Int32, is_private : Bool, connect_port : Int32?, num : Int32)
    STDERR.puts "node: #{port} #{is_private} #{connect_port} #{num}"

    args = ["-p", port, "-w", wallet(num), "--testnet"]
    args << "-n http://127.0.0.1:#{connect_port}" if connect_port

    if is_private
      args << "--private"
    else
      args << "-u"
      args << "http://127.0.0.1:#{port}"
    end

    bin = sushid(args)

    spawn do
      system("#{bin} &> #{log_path(num)}")
    end
  end
end
