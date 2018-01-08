module ::Garnet::Core::Models
  alias Sender = NamedTuple(
          address: String,
          px: String,
          py: String,
          amount: Float64,
        )

  alias Senders = Array(Sender)
end
