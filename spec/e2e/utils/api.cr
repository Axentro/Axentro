module ::E2E::Utils::API

  def sushi(args) : String
    _args = args
            .map { |arg| arg.to_s }
            .join(" ")

    bin = File.expand_path("../../../../bin/sushi", __FILE__)

    "#{bin} #{_args}"
  end

  def blockchain_size(port : Int32) : Int32
    args = ["size", "-n", "http://127.0.0.1:#{port}", "--json"]

    res = `#{sushi(args)}`

    JSON.parse(res)["size"].as_i
  end

  def block(port : Int32, index : Int32) : String
    args = ["block", "-n", "http://127.0.0.1:#{port}", "-i", index, "--json"]

    res = `#{sushi(args)}`
    res
  end

  def amount(num : Int32) : Float64
    args = ["amount", "-w", "wallets/testnet-#{num}.json", "-n", "http://127.0.0.1:4000", "-u", "--testnet", "--json"]

    res = `#{sushi(args)}`

    STDERR.puts res

    JSON.parse(res)["amount"].to_s.to_f
  end

  def create(n_sender : Int32, n_recipient : Int32)
    a = amount(n_sender)

    STDERR.puts "amount of #{n_sender}: #{a}"

    return if a == 0

    a = a / 2.0

    STDERR.puts "sending amount: #{a}"

    recipient_address = ::Sushi::Core::Wallet.from_path("wallets/testnet-#{n_recipient}.json").address

    STDERR.puts "recipient address: #{recipient_address}"

    args = ["send", "-w", "wallets/testnet-#{n_sender}.json", "-a", recipient_address, "-m", a, "-n", "http://127.0.0.1:4000", "--json", "--testnet", "--message='E2E Test'"]

    res = `#{sushi(args)}`

    STDERR.puts "res: #{res}"

    res
  end
end
