# Copyright © 2017-2020 The Axentro Core developers
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

require "json"
require "random"
require "base64"

require "/../src/core.cr"
require "/../src/core/keys/wif.cr"

class X
  def self.create_id : String
    tmp_id = Random::Secure.hex(32)
    return create_id if tmp_id[0] == "0"
    tmp_id
  end

  def self.transaction(from_wallet, to_address, iterations = 10)
    File.open("txns.txt", "w") { |f|
      (1..iterations).to_a.each do |_|
        path = File.expand_path(from_wallet, __FILE__)
        wallet_json = File.read(path)
        w = JSON.parse(wallet_json)

        id = create_id
        from_address = w["address"].as_s
        public_key = w["public_key"].as_s
        wif_string = w["wif"].as_s
        wif = Axentro::Core::Keys::Wif.new(wif_string)
        private_key = wif.private_key.as_hex

        unsigned_transaction = %Q({"id":"#{id}","action":"send","senders":[{"address":"#{from_address}","public_key":"#{public_key}","amount":100000000,"fee":10000,"signature":"0"}],"recipients":[{"address":"#{to_address}","amount":100000000}],"message":"0","token":"AXNT","prev_hash":"0","timestamp":#{Time.local.to_unix_ms},"scaled":1,"kind":"FAST"})
        transaction_hash = sha256(unsigned_transaction)

        signed_transaction = Axentro::Core::Keys::KeyUtils.sign(private_key, transaction_hash)

        txn = unsigned_transaction.gsub(%Q{"signature":"0"}, %Q{"signature":"#{signed_transaction}"})

        body = %Q({"transaction": #{txn}})
        encoded_body = Base64.encode(body).gsub("\n", "")

        f.puts %Q({"method":"POST","url":"http://localhost:3000/api/v1/transaction","body":"#{encoded_body}"})
      end
    }
  end
end

iters = 1000
X.transaction("../perf-test.json", "VDBjMjZkNzgwOWE2NWEzMzZmNjA2MmI0Njc2YzZkMWZjNWY3ODQwYjVmYWM3NmUx", iters)

# crystal perf/x.cr && vegeta attack -targets="txns.txt" -format=json -rate=1000 | vegeta encode
# crystal perf/x.cr && vegeta attack -targets="txns.txt" -format=json -rate=10 -duration=1m | vegeta encode | \
# jaggr @count=rps \
# hist\[100,200,300,400,500\]:code \
# p25,p50,p95:latency \
# sum:bytes_in \
# sum:bytes_out | \
# jplot rps+code.hist.100+code.hist.200+code.hist.300+code.hist.400+code.hist.500 \
# latency.p95+latency.p50+latency.p25 \
# bytes_in.sum+bytes_out.sum

# vegeta attack -targets="txns.txt" -format=json -rate=100 | vegeta encode

# https://github.com/tsenart/vegeta
