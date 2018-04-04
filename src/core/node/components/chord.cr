require "./node_id"

#
# todo: think about private nodes
# todo: is_successor?, is_predecessor?を実装した方が良いかも
# todo: when change the successor or predecessor, the sockets should be disconnected then.
# todo: check socket.close?
#
module ::Sushi::Core::NodeComponents
  class Chord
    @node_id : NodeID

    @successor_list : Models::Nodes = Models::Nodes.new
    @predecessor : Models::Node?

    def initialize(
      @public_host : String?,
      @public_port : Int32?,
      @ssl : Bool?,
      @network_type : String,
      @is_private : Bool,
      @use_ssl : Bool
    )
      @node_id = NodeID.new

      stabilize_process
    end

    def stabilize_process
      spawn do
        loop do
          sleep 3

          @successor_list.each do |successor|
            debug "-> successor : #{successor[:context][:host]}:#{successor[:context][:port]}"
          end

          if predecessor = @predecessor
            debug "predecessor : #{predecessor[:context][:host]}:#{predecessor[:context][:port]}"
          else
            debug "predecessor : Not found"
          end

          if @successor_list.size > 0
            successor = @successor_list[0]

            debug "request to check predecessor for " +
                  "#{successor[:context][:host]}:#{successor[:context][:port]}"

            send(
              successor[:socket],
              M_TYPE_CHORD_STABILIZE_AS_SUCCESSOR,
              {
                predecessor_context: context,
              }
            )
          end
        end
      end
    end

    def join_from(node, _content)
      _m_content = M_CONTENT_CHORD_JOIN.from_json(_content)

      _version = _m_content.version
      _context = _m_content.context

      debug "#{_context[:host]}:#{_context[:port]} try to join SushiChain"

      # todo: version check
      # todo: network type check

      search_successor(_context)
    end

    # todo: refactoring
    def connect_to_successor(node, _content : String)
      _m_content = M_CONTENT_CHORD_FOUND_SUCCESSOR.from_json(_content)

      _context = _m_content.context

      connect_to_successor(node, _context)
    end

    def connect_to_successor(node, _context : NodeContext)
      info "successor found: #{_context[:host]}:#{_context[:port]}"

      socket = HTTP::WebSocket.new(_context[:host], "/peer", _context[:port], @use_ssl)

      node.peer(socket)

      spawn do
        socket.run
      end

      # todo: refactoring?
      if @successor_list.size > 0
        @successor_list[0] = {socket: socket, context: _context}
      else
        @successor_list.push({socket: socket, context: _context})
      end
    end

    def join_to(connect_host : String, connect_port : Int32)
      debug "joining network: #{connect_host}:#{connect_port}"

      send_chord(
        connect_host,
        connect_port,
        M_TYPE_CHORD_JOIN,
        {
          version: Core::CORE_VERSION,
          context: context,
        })
    end

    def stabilize_as_successor(node, socket, _content : String)
      _m_content = M_CONTENT_CHORD_STABILIZE_AS_SCCESSOR.from_json(_content)

      _context = _m_content.predecessor_context

      debug "be asked to check predecessor by #{_context[:host]}:#{_context[:port]}"

      if predecessor = @predecessor
        predecessor_node_id = NodeID.create_from(predecessor[:context][:id])

        if @node_id < predecessor_node_id &&
           (
             @node_id > _context[:id] ||
             predecessor_node_id < _context[:id]
           )
          info "new predecessor found: #{_context[:host]}:#{_context[:port]}"
          @predecessor = {socket: socket, context: _context}
        elsif @node_id > predecessor_node_id &&
              @node_id > _context[:id] &&
              predecessor_node_id < _context[:id]
          info "new predecessor found: #{_context[:host]}:#{_context[:port]}"
          @predecessor = {socket: socket, context: _context}
        else
          debug "current predecessor #{predecessor[:context][:host]}:#{predecessor[:context][:port]} is correct"
        end
      else
        info "new predecessor found: #{_context[:host]}:#{_context[:port]}"
        @predecessor = {socket: socket, context: _context}
      end

      send(
        socket,
        M_TYPE_CHORD_STABILIZE_AS_PREDECESSOR,
        {
          successor_context: @predecessor.not_nil![:context],
        }
      )

      if @successor_list.size == 0
        connect_to_successor(node, @predecessor.not_nil![:context])
      end
    end

    def stabilize_as_predecessor(node, socket, _content : String)
      _m_content = M_CONTENT_CHORD_STABILIZE_AS_PREDECESSOR.from_json(_content)

      _context = _m_content.successor_context

      if @successor_list.size > 0
        successor = @successor_list[0]
        successor_node_id = NodeID.create_from(successor[:context][:id])

        if @node_id > successor_node_id &&
           (
             @node_id < _context[:id] ||
             successor_node_id > _context[:id]
           )
          info "new successor found: #{_context[:host]}:#{_context[:port]}"

          connect_to_successor(node, _context)
        elsif @node_id < successor_node_id &&
              @node_id < _context[:id] &&
              successor_node_id > _context[:id]
          info "new successor found: #{_context[:host]}:#{_context[:port]}"

          connect_to_successor(node, _context)
        else
          debug "current successor #{successor[:context][:host]}:#{successor[:context][:port]} is correct"
        end
      else
        # todo: remove here
        error "coming here (for debugging)"
      end
    end

    # todo: refactoring
    def search_successor(_content : String)
      _m_content = M_CONTENT_CHORD_SEARCH_SUCCESSOR.from_json(_content)

      search_successor(_m_content.context)
    end

    def search_successor(_context : Models::NodeContext)
      debug "search successor for #{_context[:host]}:#{_context[:port]}"

      if @successor_list.size > 0
        successor = @successor_list[0]
        successor_node_id = NodeID.create_from(successor[:context][:id])

        if @node_id > successor_node_id &&
           (
             @node_id < _context[:id] ||
             successor_node_id > _context[:id]
           )
          send_chord(
            _context,
            M_TYPE_CHORD_FOUND_SUCCESSOR,
            {
              context: successor[:context],
            }
          )

          # todo:
          # 自分のsuccessorをここで_contextに更新？
        elsif successor_node_id > @node_id &&
              successor_node_id > _context[:id] &&
              @node_id < _context[:id]
          send_chord(
            _context,
            M_TYPE_CHORD_FOUND_SUCCESSOR,
            {
              context: successor[:context],
            }
          )

          # todo:
          # 自分のsuccessorをここで_contextに更新？
        else
          send(
            successor[:socket],
            M_TYPE_CHORD_SEARCH_SUCCESSOR,
            {
              context: _context,
            }
          )
        end
      else
        send_chord(
          _context,
          M_TYPE_CHORD_FOUND_SUCCESSOR,
          {
            context: context,
          }
        )

        # todo:
        # 自分のsuccessorをここで_contextに更新？
      end
    end

    def context
      {
        id:         @node_id.id,
        host:       @public_host || "",
        port:       @public_port || -1,
        ssl:        @ssl || false,
        type:       @network_type,
        is_private: @is_private,
      }
    end

    def send_chord(_context : Models::NodeContext, _t : Int32, _content)
      send_chord(_context[:host], _context[:port], _t, _content)
    end

    # todo: rescue
    def send_chord(connect_host : String, connect_port : Int32, _t : Int32, _content)
      _socket = HTTP::WebSocket.new(connect_host, "/peer", connect_port, @use_ssl)
      send(_socket, _t, _content)
      _socket.close
    end

    include Logger
    include Protocol
    include Consensus
    include Common::Color
  end
end
