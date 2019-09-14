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

require "spinach"
require "./../spec_helper"

class Transactions < SpinachTestCase
  include Units::Utils

  def mapping
    {
      "send_amount": ->(args : Array(String)) { send_amount(args) },
    }
  end

  def send_amount(args)
    amount = args.first.to_s
    fee = args.last

    wallet_a = Wallet.from_json(Wallet.create(true).to_json)
    wallet_b = Wallet.from_json(Wallet.create(true).to_json)

    wallet_a_amount = Quantity.as_fund_amount("wallet_balance_a", @variables)
    wallet_b_amount = Quantity.as_fund_amount("wallet_balance_b", @variables)
    developer_fund = DeveloperFunds.with_funds([
      {"address" => wallet_a.address, "amount" => wallet_a_amount},
      {"address" => wallet_b.address, "amount" => wallet_b_amount},
      ])

    with_factory(developer_fund) do |block_factory, transaction_factory|
      amount_to_send = Quantity.as_internal_amount(amount)
      fee = Quantity.as_internal_amount("0.0001")

      senders = Transactions.single_sender(wallet_a, amount_to_send, fee)
      recipients = Transactions.single_recipient(wallet_b, amount_to_send)
      transaction = transaction_factory.make_send(amount_to_send, "SUSHI", senders, recipients, [wallet_a])

      block_factory.add_slow_block([transaction])

      wallet_a_final_balance = Wallets.balance_for(wallet_a, block_factory)
      wallet_b_final_balance = Wallets.balance_for(wallet_b, block_factory)

      rejected = block_factory.blockchain.rejects.@rejects.keys.size.to_s

      {"wallet_balance_a" => wallet_a_final_balance, "wallet_balance_b" => wallet_b_final_balance, "rejections" => rejected}
    end
  end
end
