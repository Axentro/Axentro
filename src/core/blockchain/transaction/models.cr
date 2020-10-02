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

module ::Axentro::Core::TransactionModels
  enum TransactionKind
    SLOW
    FAST

    def to_json(builder : JSON::Builder)
      builder.string(to_s)
    end
  end

  alias Sender = NamedTuple(
    address: String,
    public_key: String,
    amount: Int64,
    fee: Int64,
    signature: String)

  alias Senders = Array(Sender)

  alias SenderDecimal = NamedTuple(
    address: String,
    public_key: String,
    amount: String,
    fee: String,
    signature: String)

  alias SendersDecimal = Array(SenderDecimal)

  alias Recipient = NamedTuple(
    address: String,
    amount: Int64,
  )

  alias Recipients = Array(Recipient)

  alias RecipientDecimal = NamedTuple(
    address: String,
    amount: String,
  )

  alias RecipientsDecimal = Array(RecipientDecimal)

  alias Transactions = Array(Transaction)
end
