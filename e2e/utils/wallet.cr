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

module ::E2E::Utils::Wallet
  def wallets_path
    "../../wallets"
  end

  def create_wallet(num : Int32) : String
    `#{axe(["wt", "create", "-w", wallet(num), "--testnet"])}`
  end

  def wallet(num : Int32) : String
    File.expand_path("#{wallets_path}/testnet-#{num}.json", __FILE__)
  end

  def wallet_address(num : Int32) : String
    wallet_json = File.read(wallet(num))
    the_parsed_wallet = JSON.parse(wallet_json)
    the_parsed_wallet["address"].as_s
  end

  def developer_fund_file
    File.expand_path("#{wallets_path}/developer_fund.yml", __FILE__)
  end

  def official_nodes_file
    File.expand_path("#{wallets_path}/official_nodes.yml", __FILE__)
  end

  include ::E2E::Utils::API
end
