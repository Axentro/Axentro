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

require "./transaction/models"

module ::Sushi::Core
  class Transaction
    MESSAGE_SIZE_LIMIT = 512
    TOKEN_SIZE_LIMIT   =  16

    JSON.mapping(
      id: String,
      action: String,
      senders: Senders,
      recipients: Recipients,
      message: String,
      token: String,
      prev_hash: String,
      scaled: Int32,
    )

    setter prev_hash : String

    def initialize(
      @id : String,
      @action : String,
      @senders : Senders,
      @recipients : Recipients,
      @message : String,
      @token : String,
      @prev_hash : String,
      @scaled : Int32
    )
    end

    def self.create_id : String
      tmp_id = Random::Secure.hex(32)
      return create_id if tmp_id[0] == "0"
      tmp_id
    end

    def to_hash : String
      string = self.to_json
      sha256(string)
    end

    def valid?(blockchain : Blockchain, transactions : Array(Transaction)) : Bool
      raise "length of transaction id have to be 64: #{@id}" if @id.size != 64
      raise "message size exceeds: #{self.message.bytesize} for #{MESSAGE_SIZE_LIMIT}" if self.message.bytesize > MESSAGE_SIZE_LIMIT
      raise "token size exceeds: #{self.token.bytesize} for #{TOKEN_SIZE_LIMIT}" if self.token.bytesize > TOKEN_SIZE_LIMIT
      raise "unscaled transaction" if scaled != 1

      is_coinbase = transactions.size == 0

      secp256k1 : ECDSA::Secp256k1 = ECDSA::Secp256k1.new

      @senders.each do |sender|
        network = Keys::Address.from(sender[:address]).network
        public_key = Keys::PublicKey.new(sender[:public_key], network)

        if !secp256k1.verify(
             public_key.not_nil!.point,
             self.as_unsigned.to_hash,
             BigInt.new(sender[:sign_r], base: 16),
             BigInt.new(sender[:sign_s], base: 16),
           )
          raise "invalid signing for sender: #{sender[:address]}"
        end

        unless Keys::Address.from(sender[:address], "sender")
          raise "invalid checksum for sender's address: #{sender[:address]}"
        end

        valid_amount?(sender[:amount])
      end

      @recipients.each do |recipient|
        unless Keys::Address.from(recipient[:address], "recipient")
          raise "invalid checksum for recipient's address: #{recipient[:address]}"
        end

        valid_amount?(recipient[:amount])
      end

      if !is_coinbase
        raise "There must be some transactions" if transactions.size < 1

        if sender_total_amount != recipient_total_amount
          raise "amount mismatch for senders (#{scale_decimal(sender_total_amount)}) and recipients (#{scale_decimal(recipient_total_amount)})"
        end

        if @prev_hash != transactions[-1].to_hash
          raise "invalid prev_hash: expected #{transactions[-1].to_hash} but got #{@prev_hash}"
        end

        # omg...
        blockchain.dapps.each do |dapp|
          dapp.valid?(self, transactions) if dapp.transaction_related?(@action)
        end
      else
        raise "actions has to be 'head' for coinbase transaction " if @action != "head"
        raise "message has to be '0' for coinbase transaction" if @message != "0"
        raise "token has to be #{TOKEN_DEFAULT} for coinbase transaction" if @token != TOKEN_DEFAULT
        raise "there should be no Sender for a coinbase transaction" if @senders.size != 0
        raise "prev_hash of coinbase transaction has to be '0'" if @prev_hash != "0"

        served_sum = @recipients.reduce(0_i64) { |sum, recipient| sum + recipient[:amount] }
        served_sum_expected = blockchain.latest_block.coinbase_amount

        if served_sum != served_sum_expected
          raise "invalid served amount for coinbase transaction: " +
                "expected #{served_sum_expected} but got #{served_sum} "
        end
      end

      true
    end

    def as_unsigned : Transaction
      unsigned_senders = self.senders.map { |s|
        {
          address:    s[:address],
          public_key: s[:public_key],
          amount:     s[:amount],
          fee:        s[:fee],
          sign_r:     "0",
          sign_s:     "0",
        }
      }

      Transaction.new(
        self.id,
        self.action,
        unsigned_senders,
        self.recipients,
        self.message,
        self.token,
        "0",
        self.scaled,
      )
    end

    def as_signed(wallets : Array(Wallet)) : Transaction
      secp256k1 = Core::ECDSA::Secp256k1.new

      signed_senders = self.senders.map_with_index { |s, i|
        private_key = Wif.new(wallets[i].wif).private_key

        sign = secp256k1.sign(private_key.as_big_i, self.to_hash)

        {
          address: s[:address],
          public_key: s[:public_key],
          amount: s[:amount],
          fee: s[:fee],
          sign_r: sign[0].to_s(base: 16),
          sign_s: sign[1].to_s(base: 16),
        }
      }

      Transaction.new(
        self.id,
        self.action,
        signed_senders,
        self.recipients,
        self.message,
        self.token,
        "0",
        self.scaled,
      )
    end

    def sender_total_amount : Int64
      senders.reduce(0_i64) { |sum, sender| sum + sender[:amount] }
    end

    def recipient_total_amount : Int64
      recipients.reduce(0_i64) { |sum, recipient| sum + recipient[:amount] }
    end

    def total_fees : Int64
      senders.reduce(0_i64) { |sum, sender| sum + sender[:fee] }
    end

    include Hashes
    include TransactionModels
    include Common::Validator
    include Common::Denomination
  end
end

require "./transaction/*"
