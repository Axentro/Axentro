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

module ::Axentro::Core
  class MinerRewardCalculator
    getter miner_rewards_total : Float64

    def initialize(@miner_nonces : Array(MinerNonce), @coinbase_amount : Int64, @fastnode_recipients : Array(Transaction::Recipient), @is_fastnode : Bool, @wallet_address : String, @fee : Int64)
      @miner_rewards_total = @coinbase_amount * 0.75
    end

    def miner_rewards_as_recipients : Array(Transaction::Recipient)
      @miner_nonces.group_by { |mn| mn.address }.flat_map do |address, nonces|
        amount = (@miner_rewards_total * nonces.size) / @miner_nonces.size
        {address: address, amount: amount.to_i64}
      end.reject { |m| m[:amount] == 0_i64 }
    end

    def node_rewards_as_recipients(miners_recipients : Array(Transaction::Recipient)) : Array(Transaction::Recipient)
      node_recipients : Array(Transaction::Recipient) = [] of Transaction::Recipient
      node_recipient_amount = @coinbase_amount - miners_recipients.reduce(0_i64) { |sum, m| sum + m[:amount] }

      if @is_fastnode
        node_recipients << {
          address: @wallet_address,
          amount:  node_recipient_amount + @fee,
        }
      else
        node_recipients << {
          address: @wallet_address,
          amount:  node_recipient_amount,
        }
        node_recipients += @fastnode_recipients
      end
      node_recipients
    end

    include Logger
  end
end
