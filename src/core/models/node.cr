module ::Sushi::Core::Models
  alias NodeContext = NamedTuple(
    id: String,
    host: String,
    port: Int32,
    type: String,
    is_private: Bool,
  )

  alias NodeContexts = Array(NodeContext)

  alias Node = NamedTuple(
    context: NodeContext,
    socket: HTTP::WebSocket,
  )

  alias Nodes = Array(Node)
end
