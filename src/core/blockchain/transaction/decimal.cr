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

module ::Sushi::Core
  class TransactionDecimal
    JSON.mapping(
      id: String,
      action: String,
      senders: SendersDecimal,
      recipients: RecipientsDecimal,
      message: String,
      token: String,
      prev_hash: String,
      timestamp: Int64,
      scaled: Int32,
    )

    def initialize(
      @id : String,
      @action : String,
      @senders : SendersDecimal,
      @recipients : RecipientsDecimal,
      @message : String,
      @token : String,
      @prev_hash : String,
      @timestamp : Int64,
      @scaled : Int32
    )
      raise "invalid decimal transaction (expected scaled: 0 but received #{@scaled})" if @scaled != 0
    end

    def to_transaction : Transaction
      Transaction.new(
        @id,
        @action,
        scale_i64(@senders),
        scale_i64(@recipients),
        @message,
        @token,
        @prev_hash,
        @timestamp,
        1,
      )
    end

    private def scale_i64(senders : SendersDecimal) : Senders
      senders.map { |s| scale_i64(s) }
    end

    private def scale_i64(sender : SenderDecimal) : Sender
      {
        address:    sender[:address],
        public_key: sender[:public_key],
        amount:     scale_i64(sender[:amount]),
        fee:        scale_i64(sender[:fee]),
        sign_r:     sender[:sign_r],
        sign_s:     sender[:sign_s],
      }
    end

    private def scale_i64(recipients : RecipientsDecimal) : Recipients
      recipients.map { |r| scale_i64(r) }
    end

    private def scale_i64(recipient : RecipientDecimal) : Recipient
      {
        address: recipient[:address],
        amount:  scale_i64(recipient[:amount]),
      }
    end

    private def scale_decimal(senders : Senders) : SendersDecimal
      senders.map { |s| scale_decimal(s) }
    end

    private def scale_decimal(sender : Sender) : SenderDecimal
      {
        address:    sender[:address],
        public_key: sender[:public_key],
        amount:     scale_decimal(sender[:amount]),
        fee:        scale_decimal(sender[:fee]),
        sign_r:     sender[:sign_r],
        sign_s:     sender[:sign_s],
      }
    end

    private def scale_decimal(recipients : Recipients) : RecipientsDecimal
      recipients.map { |r| scale_decimal(r) }
    end

    private def scale_decimal(recipient : Recipient) : RecipientDecimal
      {
        address: recipient[:address],
        amount:  scale_decimal(recipient[:amount]),
      }
    end

    include Common::Denomination
    include TransactionModels
  end
end
