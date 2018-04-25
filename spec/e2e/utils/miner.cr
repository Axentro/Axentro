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

module ::E2E::Utils::Miner
  def sushim(args) : String
    _args = args
      .map { |arg| arg.to_s }
      .join(" ")

    bin = File.expand_path("../../../../bin/sushim", __FILE__)

    "#{bin} #{_args}"
  end

  def mining(port : Int32, num : Int32)
    args = ["-w", "wallets/testnet-#{num}.json", "-n", "http://127.0.0.1:#{port}", "--testnet"]

    bin = sushim(args)

    spawn do
      system("#{bin} &> #{log_path(num, true)}")
    end
  end
end
