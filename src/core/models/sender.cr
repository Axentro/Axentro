module ::Sushi::Core::Models
  alias Sender = NamedTuple(
    address: String,
    px: String,
    py: String,
    amount: Int64,
  )

  alias Senders = Array(Sender)
end
