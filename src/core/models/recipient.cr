module ::Sushi::Core::Models
  alias Recipient = NamedTuple(
          address: String,
          amount: Int64,
        )

  alias Recipients = Array(Recipient)
end
