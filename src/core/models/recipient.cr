module ::Sushi::Core::Models
  alias Recipient = NamedTuple(
          address: String,
          amount: Float64,
        )

  alias Recipients = Array(Recipient)
end
