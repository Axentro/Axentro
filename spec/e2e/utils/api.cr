module ::E2E::Utils::API
  def sushi(args) : String
    _args = args
      .map { |arg| arg.to_s }
      .join(" ")

    bin = File.expand_path("../../../../bin/sushi", __FILE__)

    "#{bin} #{_args}"
  end

  def blockchain_size(port : Int32) : Int32
    args = ["blockchain", "size", "-n", "http://127.0.0.1:#{port}", "--json"]

    res = `#{sushi(args)}`

    JSON.parse(res)["size"].as_i
  end

  def block(port : Int32, index : Int32) : String
    args = ["blockchain", "block", "-n", "http://127.0.0.1:#{port}", "-i", index, "--json"]

    res = `#{sushi(args)}`
    res
  end

  def amount(port : Int32, num : Int32, unconfirmed = false) : Int64
    args = ["wallet", "amount", "-w", "wallets/testnet-#{num}.json", "-n", "http://127.0.0.1:#{port}", "--json"]
    args << "-u" if unconfirmed

    res = `#{sushi(args)}`

    JSON.parse(res)["result"][0]["amount"].to_s.to_i64
  end

  def create(port : Int32, n_sender : Int32, n_recipient : Int32) : String?
    a = amount(port, n_sender, true)

    return nil if a == 0

    a = Random.rand(a/10000) + 1

    recipient_address = ::Sushi::Core::Wallet.from_path("wallets/testnet-#{n_recipient}.json").address

    args = ["transaction", "send", "-w", "wallets/testnet-#{n_sender}.json", "-a", recipient_address, "-m", a, "-n", "http://127.0.0.1:#{port}", "--message='E2E Test'", "-f", "1", "--json"]

    res = `#{sushi(args)}`

    JSON.parse(res)["id"].to_s
  end

  def transaction(port : Int32, transaction_id : String)
    args = ["transaction", "transaction", "-t", transaction_id, "-n", "http://127.0.0.1:#{port}", "--json"]

    res = `#{sushi(args)}`
    res
  end
end
