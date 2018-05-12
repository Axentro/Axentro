module ::Sushi::Core::TransactionModels
  alias Sender = NamedTuple(
    address: String,
    public_key: String,
    amount: Int64,
    fee: Int64,
  )

  alias Senders = Array(Sender)

  alias SenderDecimal = NamedTuple(
    address: String,
    public_key: String,
    amount: String,
    fee: String,
  )

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
end
