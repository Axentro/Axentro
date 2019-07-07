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
      timestamp: Int64,
      scaled: Int32,
    )

    setter prev_hash : String

    @common_checked : Bool = false

    def initialize(
      @id : String,
      @action : String,
      @senders : Senders,
      @recipients : Recipients,
      @message : String,
      @token : String,
      @prev_hash : String,
      @timestamp : Int64,
      @scaled : Int32
    )
    end

    def self.create_id : String
      tmp_id = Random::Secure.hex(32)
      return create_id if tmp_id[0] == "0"
      tmp_id
    end

    # def self.secp256k1 : ECDSA::Secp256k1
    #   @@secp256k1 ||= ECDSA::Secp256k1.new
    #   @@secp256k1.not_nil!
    # end
    #
    # def secp256k1
    #   Transaction.secp256k1
    # end

    def to_hash : String
      string = self.to_json
      sha256(string)
    end

    def short_id : String
      @id[0..7]
    end

    def valid_as_embedded?(blockchain : Blockchain, prev_transactions : Array(Transaction)) : Bool
      verbose "tx -- #{short_id}: validating embedded transactions"

      # TODO: Definitely needs changing, but to what?
      raise "be not checked signing" unless @common_checked

      if sender_total_amount != recipient_total_amount
        raise "amount mismatch for senders (#{scale_decimal(sender_total_amount)}) " +
              "and recipients (#{scale_decimal(recipient_total_amount)})"
      end

      if @prev_hash != prev_transactions[-1].to_hash
        raise "invalid prev_hash: expected #{prev_transactions[-1].to_hash} but got #{@prev_hash}"
      end

      blockchain.dapps.each do |dapp|
        if dapp.transaction_related?(@action) && prev_transactions.size > 0
          dapp.valid?(self, prev_transactions)
        end
      end

      true
    end

    def valid_as_coinbase?(blockchain : Blockchain, block_index : Int64, embedded_transactions : Array(Transaction)) : Bool
      verbose "tx -- #{short_id}: validating coinbase transaction"

      # TODO: See above comment
      raise "be not checked signing" unless @common_checked

      raise "actions has to be 'head' for coinbase transaction " if @action != "head"
      raise "message has to be '0' for coinbase transaction" if @message != "0"
      raise "token has to be #{TOKEN_DEFAULT} for coinbase transaction" if @token != TOKEN_DEFAULT
      raise "there should be no Sender for a coinbase transaction" if @senders.size != 0
      raise "prev_hash of coinbase transaction has to be '0'" if @prev_hash != "0"

      served_sum = @recipients.reduce(0_i64) { |sum, recipient| sum + recipient[:amount] }
      served_sum_expected = blockchain.coinbase_amount(block_index, embedded_transactions, blockchain.get_premine_total_amount)

      if served_sum != served_sum_expected
        raise "invalid served amount for coinbase transaction: " +
              "expected #{served_sum_expected} but got #{served_sum} "
      end

      true
    end

    def valid_common? : Bool
      return true if @common_checked

      verbose "tx -- #{short_id}: validating common"

      raise "length of transaction id has to be 64: #{@id}" if @id.size != 64
      raise "message size exceeds: #{self.message.bytesize} for #{MESSAGE_SIZE_LIMIT}" if self.message.bytesize > MESSAGE_SIZE_LIMIT
      raise "token size exceeds: #{self.token.bytesize} for #{TOKEN_SIZE_LIMIT}" if self.token.bytesize > TOKEN_SIZE_LIMIT
      raise "unscaled transaction" if @scaled != 1

      @senders.each do |sender|
        network = Keys::Address.from(sender[:address], "sender").network
        public_key = Keys::PublicKey.new(sender[:public_key], network)

        if !ECCrypto.verify(
             public_key.as_hex,
             self.as_unsigned.to_hash,
             sender[:sign_r],
             sender[:sign_s]
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

      @common_checked = true

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
        self.timestamp,
        self.scaled,
      )
    end

    def as_signed(wallets : Array(Wallet)) : Transaction
      signed_senders = self.senders.map_with_index { |s, i|
        private_key = Wif.new(wallets[i].wif).private_key

        sign = ECCrypto.sign(private_key.as_hex, self.to_hash)

        {
          address:    s[:address],
          public_key: s[:public_key],
          amount:     s[:amount],
          fee:        s[:fee],
          sign_r:     sign["r"],
          sign_s:     sign["s"],
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
        self.timestamp,
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

    #
    # ignore prev_hash for comparison
    #
    def ==(other : Transaction) : Bool
      return false unless @id == other.id
      return false unless @action == other.action
      return false unless @senders == other.senders
      return false unless @recipients == other.recipients
      return false unless @token == other.token
      return false unless @timestamp == other.timestamp
      return false unless @scaled == other.scaled

      true
    end

    include Hashes
    include Logger
    include TransactionModels
    include Common::Validator
    include Common::Denomination
  end
end

require "./transaction/*"
