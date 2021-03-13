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
require "json"

module ::Axentro::Core::TransactionModels
  enum TransactionKind
    SLOW
    FAST

    def to_json(j : JSON::Builder)
      j.string(to_s)
    end
  end

  enum TransactionVersion
    V1

    def to_json(j : JSON::Builder)
      j.string(to_s)
    end
  end

  # alias Sender = NamedTuple(
  #   address: String,
  #   public_key: String,
  #   amount: Int64,
  #   fee: Int64,
  #   signature: String)

  class Sender
    include JSON::Serializable
    property address : String
    property public_key : String
    property amount : Int64
    property fee : Int64
    property signature : String

    def initialize(@address, @public_key, @amount, @fee, @signature); end

    def to_json(j : JSON::Builder)
      j.object do
        j.field("address", @address)
        j.field("public_key", @public_key)
        j.field("amount", @amount)
        j.field("fee", @fee)
        j.field("signature", @signature)
      end
    end
  end

  alias Senders = Array(Sender)

  alias SenderDecimal = NamedTuple(
    address: String,
    public_key: String,
    amount: String,
    fee: String,
    signature: String)

  alias SendersDecimal = Array(SenderDecimal)

  # alias Recipient = NamedTuple(
  #   address: String,
  #   amount: Int64,
  # )

  class Recipient
    include JSON::Serializable
    property address : String
    property amount : Int64

    def initialize(@address, @amount); end

    def to_json(j : JSON::Builder)
      j.object do
        j.field("address", @address)
        j.field("amount", @amount)
      end
    end
  end

  alias Recipients = Array(Recipient)

  alias RecipientDecimal = NamedTuple(
    address: String,
    amount: String,
  )

  alias RecipientsDecimal = Array(RecipientDecimal)

  alias Transactions = Array(Transaction)
end
