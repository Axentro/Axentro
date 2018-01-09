module ::Garnet::Core::Models
  alias Miner = NamedTuple(
          address: String,
          socket: HTTP::WebSocket,
          nonces: Array(UInt64),
        )

  alias Miners = Array(Miner)
end
