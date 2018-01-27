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
end
