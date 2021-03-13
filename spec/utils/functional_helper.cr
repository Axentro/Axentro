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
module FunctionalHelper
  include Axentro::Core
  include Axentro::Common::Denomination

  class Quantity
    def self.as_internal_amount(variable_name : String, variables) : Int64
      scale_i64(variables[variable_name]["value"])
    end

    def self.as_internal_amount(value : String) : Int64
      scale_i64(value)
    end

    def self.as_fund_amount(variable_name : String, variables) : String
      scale_i64(scale_decimal(variables[variable_name]["value"].to_i64)).to_s
    end

    def self.as_human_amount(amount : Int64) : String
      scale_decimal(amount)
    end
  end

  class Transactions
    def self.single_sender(wallet, amount, fee) : Array(Transaction::Sender)
      [Sender.new(wallet.address,
        wallet.public_key,
        amount,
        fee,
        "0")]
    end

    def self.single_recipient(wallet, amount) : Array(Transaction::Recipient)
      [Recipient.new(wallet.address, amount)]
    end
  end

  class Wallets
    def self.balance_for(wallet, block_factory, token : String = "AXNT")
      historic_per_address = block_factory.database.get_address_amounts([wallet.address])
      Quantity.as_human_amount(block_factory.blockchain.utxo.get_for_batch(wallet.address, token, historic_per_address))
    end

    def self.create
      Wallet.from_json(Wallet.create(true).to_json)
    end
  end

  class DeveloperFunds
    def self.with_funds(funding_array)
      config_override = DeveloperFundConfig.new(funding_array)
      developer_fund = DeveloperFund.new("#{__DIR__}/data/developer_fund.yml")
      developer_fund.set_config(config_override)
      developer_fund
    end
  end
end
