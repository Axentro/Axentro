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

module ::E2E::Utils::API
  def sushi(args) : String
    _args = args
      .map { |arg| arg.to_s }
      .join(" ")

    bin = File.expand_path("../../../bin/sushi", __FILE__)

    "#{bin} #{_args}"
  end

  def blockchain_size(port : Int32) : Int32
    args = ["blockchain", "size", "-n", "http://127.0.0.1:#{port}", "--json"]

    res = `#{sushi(args)}`

    if json = parse_json(res)
      return json["totals"]["total_size"].as_i
    end

    0
  end

  def block(port : Int32, index : Int32) : JSON::Any?
    args = ["blockchain", "block", "-n", "http://127.0.0.1:#{port}", "-i", index, "--json"]

    res = `#{sushi(args)}`

    if parsed_res = parse_json(res)
      parsed_res["index"]
      parsed_res
    end
  rescue e : Exception
    nil
  end

  def amount(port : Int32, num : Int32) : BigDecimal
    args = ["wallet", "amount", "-w", wallet(num), "-n", "http://127.0.0.1:#{port}", "--json"]

    res = `#{sushi(args)}`

    if json = parse_json(res)
      if json["error"]?
        puts "Error: #{json["message"]}"
        return BigDecimal.new(0)
      end

      return BigDecimal.new(json["pairs"][0]["amount"].as_s)
    end

    BigDecimal.new(0)
  end

  def create(port : Int32, n_sender : Int32, n_recipient : Int32, fast_transaction : Bool) : String?
    a = amount(port, n_sender)

    return nil if a < BigDecimal.new("0.00010001")

    recipient_address = ::Sushi::Core::Wallet.from_path(wallet(n_recipient)).address

    args = ["transaction", "create", "-w", wallet(n_sender), "-a", recipient_address, "-m", "0.00000001", "-n", "http://127.0.0.1:#{port}", "--message='E2E Test'", "-f", "0.0001", "--json"]
    args << "--fast-transaction" if fast_transaction

    res = `#{sushi(args)}`

    if json = parse_json(res)
      return json["id"].to_s
    end

    nil
  end

  def transaction(port : Int32, transaction_id : String)
    args = ["transaction", "transaction", "-t", transaction_id, "-n", "http://127.0.0.1:#{port}", "--json"]

    res = `#{sushi(args)}`
    res
  end

  def parse_json(command_res : String) : JSON::Any?
    JSON.parse(command_res)
  rescue e : Exception
    STDERR.puts "invalid json found during executing API"
    STDERR.puts "original message"
    STDERR.puts command_res

    nil
  end

  include ::Sushi::Common::Denomination
end
