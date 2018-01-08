module ::Garnet::Core::Models
  alias NodeContext = NamedTuple(
          id: String,
          host: String,
          port: Int32,
        )

  alias NodeContexts = Array(NodeContext)

  alias Node = NamedTuple(
          context: NodeContext,
          socket: HTTP::WebSocket,
        )

  alias Nodes = Array(Node)
end
