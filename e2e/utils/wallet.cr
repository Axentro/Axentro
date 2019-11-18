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

module ::E2E::Utils::Wallet

  def wallets_path
    "../../wallets"
  end

  def create_wallet(num : Int32) : String
    `#{sushi(["wt", "create", "-w", wallet(num), "--testnet"])}`
  end

  def wallet(num : Int32) : String
    File.expand_path("#{wallets_path}/testnet-#{num}.json", __FILE__)
  end

  def developer_fund_file
    File.expand_path("#{wallets_path}/developer_fund.yml", __FILE__)
  end

  include ::E2E::Utils::API
end
