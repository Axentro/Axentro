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

module ::Utils::Integration
  def bin
    File.expand_path("../../../../bin", __FILE__)
  end

  def exec_sushi(args : Array(String)) : String
    `#{bin}/sushi #{args.join(" ")}`
  end

  def wallet(num : Int32) : String
    File.expand_path("../../wallets/testnet-#{num}.json", __FILE__)
  end
end
