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

module ::E2E::Utils::Miner
  def axem(args) : String
    _args = args
      .join(" ", &.to_s)

    bin = File.expand_path("../../../bin/axem", __FILE__)

    "#{bin} #{_args}"
  end

  def mining(port : Int32, num : Int32)
    args = ["-w", "wallets/testnet-#{num}.json", "-n", "http://127.0.0.1:#{port}", "--testnet"]

    bin = axem(args)

    spawn do
      system("rm -rf #{log_path(num, "miner")} && #{Envs.setup_env} && #{bin} &> #{log_path(num, "miner")}")
    end
  end
end
