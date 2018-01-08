module ::Garnet::Core::Models
  alias Miner = NamedTuple(
          address: String,
          socket: HTTP::WebSocket,
        )

  alias Miners = Array(Miner)
end
