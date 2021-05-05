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

require "./../../spec_helper"

include Units::Utils
include Axentro::Core
include Axentro::Core::TransactionModels
include ::Axentro::Common::Denomination
include Hashes

describe MinerRewardCalculator do
  it "should return the correct block reward based on the supplied index with init" do
    with_factory do |block_factory, _|
      coinbase_amount = block_factory.blockchain.coinbase_slow_amount(0, [] of Transaction)

      nonces =
        [
          nonce(17, "miner_1"), nonce(18, "miner_1"), nonce(19, "miner_1"), nonce(18, "miner_1"), nonce(17, "miner_1"),
          nonce(17, "miner_2"), nonce(18, "miner_2"), nonce(19, "miner_2"), nonce(18, "miner_2"),
          nonce(1, "miner_3"), nonce(2, "miner_3"), nonce(1, "miner_3"), nonce(1, "miner_3"),
          nonce(30, "miner_4"), nonce(30, "miner_4"), nonce(29, "miner_4"), nonce(27, "miner_4"),
        ]
      calculator = MinerRewardCalculator.new(nonces, coinbase_amount, [] of Transaction::Recipient, false, block_factory.node_wallet.address, 0_i64)
      expected = [Recipient.new("miner_1", 284042553_i64),
                  Recipient.new("miner_2", 229787234_i64),
                  Recipient.new("miner_3", 15957446_i64),
                  Recipient.new("miner_4", 370212765_i64)]
      calculator.miner_rewards_as_recipients.each_with_index do |r, i|
        r.address.should eq(expected[i].address)
        r.amount.should eq(expected[i].amount)
      end
    end
  end
end

def nonce(difficulty : Int32, miner_address : String) : MinerNonce
  MinerNonce.new("0").with_difficulty(difficulty).with_address(miner_address)
end
