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

  enum BlockVersion
    V1
    V2

    def to_json(j : JSON::Builder)
      j.string(to_s)
    end
  end

  enum HashVersion
    V1
    V2

    def to_json(j : JSON::Builder)
      j.string(to_s)
    end
  end

  enum MiningVersion
    V1
    V2

    def to_json(j : JSON::Builder)
      j.string(to_s)
    end
  end

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

  class Asset
    include JSON::Serializable
    property asset_id : String
    property name : String
    property description : String
    property media_location : String
    property media_hash : String
    property quantity : Int32
    property terms : String
    property locked : Int32
    property version : Int32
    property timestamp : Int64

    def initialize(@asset_id, @name, @description, @media_location, @media_hash, @quantity, @terms, @locked, @version, @timestamp); end

    def self.create_id : String
      tmp_id = Random::Secure.hex(32)
      return create_id if tmp_id[0] == "0"
      tmp_id
    end

    def to_json(j : JSON::Builder)
      j.object do
        j.field("asset_id", @asset_id)
        j.field("name", @name)
        j.field("description", @description)
        j.field("media_location", @media_location)
        j.field("media_hash", @media_hash)
        j.field("quantity", @quantity)
        j.field("terms", @terms)
        j.field("locked", @locked)
        j.field("version", @version)
        j.field("timestamp", @timestamp)
      end
    end

    def ==(other : Asset) : Bool
      return false unless @asset_id == other.asset_id
      return false unless @name == other.name
      return false unless @description == other.description
      return false unless @media_location == other.media_location
      return false unless @media_hash == other.media_hash
      return false unless @quantity == other.quantity
      return false unless @terms == other.terms
      return false unless @locked == other.locked
      return false unless @version == other.version
      return false unless @timestamp == other.timestamp

      true
    end
  end

  alias Assets = Array(Asset)
end
