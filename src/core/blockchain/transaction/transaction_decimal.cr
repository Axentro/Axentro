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
      sign_r: String,
      sign_s: String,
      scaled: Bool,
    )

    def initialize(
         @id : String,
         @action : String,
         @senders : SendersDecimal,
         @recipients : RecipientsDecimal,
         @message : String,
         @token : String,
         @prev_hash : String,
         @sign_r : String,
         @sign_s : String,
         @scaled : Bool,
       )
    end

    def create_unsigned_transaction_decimal(
         action : String,
         senders : SendersDecimal,
         recipients : RecipientsDecimal,
         message : String,
         token : String,
         id = Transaction.create_id) : TransactionDecimal
      TransactionDecimal.new(
        id,
        action,
        senders,
        recipients,
        message,
        token,
        "0", # prev_hash
        "0", # sign_r
        "0", # sign_s
        false,
      )
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
        @sign_r,
        @sign_s,
        true,
      )
    end

    def self.from_transaction(transaction : Transaction) : TransactionDecimal
      TransactionDecimal.new(
        transaction.id,
        transaction.action,
        scale_decimal(transaction.senders),
        scale_decimal(transaction.recipients),
        transaction.message,
        transaction.token,
        transaction.prev_hash,
        transaction.sign_r,
        transaction.sign_s,
        false,
      )
    end

    private def scale_i64(senders : SendersDecimal) : Senders
      senders.map { |s| scale_i64(s) }
    end

    private def scale_i64(sender : SenderDecimal) : Sender
      {
        address: sender[:address],
        public_key: sender[:public_key],
        amount: scale_i64(sender[:amount]),
        fee: scale_i64(sender[:fee]),
      }
    end

    private def scale_i64(recipients : RecipientsDecimal) : Recipients
      recipients.map { |r| scale_i64(r) }
    end

    private def scale_i64(recipient : RecipientDecimal) : Recipient
      {
        address: recipient[:address],
        amount: scale_i64(recipient[:amount]),
      }
    end

    private def scale_decimal(senders : Senders) : SendersDecimal
      senders.map { |s| scale_decimal(s) }
    end

    private def scale_decimal(sender : Sender) : SenderDecimal
      {
        address: sender[:address],
        public_key: sender[:public_key],
        amount: scale_decimal(sender[:amount]),
        fee: scale_decimal(sender[:fee]),
      }
    end

    private def scale_decimal(recipients : Recipients) : RecipientsDecimal
      recipients.map { |r| scale_decimal(r) }
    end

    private def scale_decimal(recipient : Recipient) : RecipientDecimal
      {
        address: recipient[:address],
        amount: scale_decimal(recipient[:amount]),
      }
    end

    include Common::Denomination
    include TransactionModels
  end
end
