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
  class FastNode
    FASTNODE_TOKEN = "FASTNODE"

    def self.validate(address : String | Nil)
      if address
        raise("Fastnode address must be a valid address - you supplied #{address}") unless Keys::Address.is_valid?(address)
      end
      address
    end

    def self.transactions(address : String)
      recipients = [
        {address: address, amount: "9000000"},
      ]

      transaction_id = Transaction.create_id
      [TransactionDecimal.new(
        transaction_id,
        "head",
        [] of Transaction::SenderDecimal,
        recipients,
        "0",            # message
        FASTNODE_TOKEN, # token
        "0",            # prev_hash
        0,              # timestamp
        0,              # scaled
        TransactionKind::SLOW,
        TransactionVersion::V1
      ).to_transaction]
    end
  end

  include TransactionModels
end
