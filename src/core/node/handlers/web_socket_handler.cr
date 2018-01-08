module ::Garnet::Core
  class WebSocketHandler < HTTP::WebSocketHandler
    def initialize(@path : String, &@proc : HTTP::WebSocket, HTTP::Server::Context -> Void)
    end

    def call(context : HTTP::Server::Context)
      super(context)
    end
  end
end
