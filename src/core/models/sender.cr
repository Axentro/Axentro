module ::Sushi::Core::Models
  alias Sender = NamedTuple(
    address: String,
    public_key: String,
    amount: Int64,
    fee: Int64,
  )

  alias Senders = Array(Sender)
end
