# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "./node_id"

module ::Sushi::Core::NodeComponents
  class Chord
    SUCCESSOR_LIST_SIZE = 3

    alias NodeContext = NamedTuple(
      id: String,
      host: String,
      port: Int32,
      ssl: Bool,
      type: String,
      is_private: Bool,
    )

    alias NodeContexts = Array(NodeContext)

    alias Node = NamedTuple(
      context: NodeContext,
      socket: HTTP::WebSocket,
    )

    alias Nodes = Array(Node)

    @node_id : NodeID

    @successor_list : Nodes = Nodes.new
    @predecessor : Node?

    @private_nodes : Nodes = Nodes.new

    @show_network = 0

    def initialize(
      @public_host : String?,
      @public_port : Int32?,
      @ssl : Bool?,
      @network_type : String,
      @is_private : Bool,
      @use_ssl : Bool
    )
      @node_id = NodeID.new

      stabilize_process unless @is_private
    end

    def join_to(connect_host : String, connect_port : Int32)
      debug "joining network: #{connect_host}:#{connect_port}"

      send_once(
        connect_host,
        connect_port,
        M_TYPE_CHORD_JOIN,
        {
          version: Core::CORE_VERSION,
          context: context,
        })
    end

    def join_to_private(node, connect_host : String, connect_port : Int32)
      debug "joining network: #{connect_host}:#{connect_port} (private)"

      socket = HTTP::WebSocket.new(connect_host, "/peer", connect_port, @use_ssl)

      node.peer(socket)

      spawn do
        socket.run
      end

      send(
        socket,
        M_TYPE_CHORD_JOIN_PRIVATE,
        {
          version: Core::CORE_VERSION,
          context: context,
        }
      )
    end

    def join(node, socket, _content)
      _m_content = M_CONTENT_CHORD_JOIN.from_json(_content)

      _version = _m_content.version
      _context = _m_content.context

      debug "#{_context[:host]}:#{_context[:port]} try to join SushiChain"

      unless _context[:type] == @network_type
        return send_once(
          socket,
          M_TYPE_CHORD_JOIN_REJECTED,
          {
            reason: "network type mismatch. " +
                    "your network: #{_context[:type]}, our network: #{@network_type}",
          }
        )
      end

      search_successor(node, _context)
    end

    def join_private(node, socket, _content)
      _m_content = M_CONTENT_CHORD_JOIN_PRIVATE.from_json(_content)

      _version = _m_content.version
      _context = _m_content.context

      debug "private node try to join SushiChain"

      unless _context[:type] == @network_type
        return send(
          socket,
          M_TYPE_CHORD_JOIN_REJECTED,
          {
            reason: "network type mismatch. " +
                    "your network: #{_context[:type]}, our network: #{@network_type}",
          }
        )
      end

      @private_nodes << {
        socket:  socket,
        context: _context,
      }

      send(
        socket,
        M_TYPE_CHORD_JOIN_PRIVATE_ACCEPTED,
        {
          context: context,
        }
      )
    end

    def join_private_accepted(node, socket, _content)
      _m_content = M_CONTENT_CHORD_JOIN_PRIVATE_ACCEPTED.from_json(_content)

      _context = _m_content.context

      debug "successfully joined to the network"

      @successor_list.push({
        socket:  socket,
        context: _context,
      })

      node.flag = FLAG_BLOCKCHAIN_LOADING
      node.proceed_setup
    end

    def join_rejected(node, socket, _content)
      _m_content = M_CONTENT_CHORD_JOIN_REJECTED.from_json(_content)

      _reason = _m_content.reason

      error "joining network was rejected."
      error "the reason: #{_reason}"
      error "the node will be exitted with -1."

      exit -1
    end

    def found_successor(node, _content : String)
      _m_content = M_CONTENT_CHORD_FOUND_SUCCESSOR.from_json(_content)
      _context = _m_content.context

      connect_to_successor(node, _context)

      node.flag = FLAG_BLOCKCHAIN_LOADING
      node.proceed_setup
    end

    def stabilize_as_successor(node, socket, _content : String)
      _m_content = M_CONTENT_CHORD_STABILIZE_AS_SCCESSOR.from_json(_content)

      _context = _m_content.predecessor_context

      if predecessor = @predecessor
        predecessor_node_id = NodeID.create_from(predecessor[:context][:id])

        if @node_id < predecessor_node_id &&
           (
             @node_id > _context[:id] ||
             predecessor_node_id < _context[:id]
           )
          info "found new predecessor: #{_context[:host]}:#{_context[:port]}"
          @predecessor = {socket: socket, context: _context}
        elsif @node_id > predecessor_node_id &&
              @node_id > _context[:id] &&
              predecessor_node_id < _context[:id]
          info "found new predecessor: #{_context[:host]}:#{_context[:port]}"
          @predecessor = {socket: socket, context: _context}
        end
      else
        info "found new predecessor: #{_context[:host]}:#{_context[:port]}"
        @predecessor = {socket: socket, context: _context}
      end

      send_overlay(
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
          connect_to_successor(node, _context)
        elsif @node_id < successor_node_id &&
              @node_id < _context[:id] &&
              successor_node_id > _context[:id]
          connect_to_successor(node, _context)
        end
      end
    end

    def debug_table_line(col0 : String, col1 : String, delimiter = "|")
      debug "#{delimiter} %20s #{delimiter} %20s #{delimiter}" % [col0, col1]
    end

    def stabilize_process
      spawn do
        loop do
          sleep Random.rand

          if (@show_network += 1) % 20 == 0
            debug_table_line("-" * 20, "-" * 20, "+")

            if @successor_list.size > 0
              @successor_list.each_with_index do |successor, i|
                debug_table_line "successor (#{i})",
                  "#{successor[:context][:host]}:#{successor[:context][:port]}"
              end
            else
              debug_table_line "successor", "Not found"
            end

            if predecessor = @predecessor
              debug_table_line "predecessor",
                "#{predecessor[:context][:host]}:#{predecessor[:context][:port]}"
            else
              debug_table_line "predecessor", "Not found"
            end

            if @private_nodes.size > 0
              debug_table_line "private nodes", @private_nodes.size.to_s
            end

            debug_table_line("-" * 20, "-" * 20, "+")
          end

          ping_all

          align_successors
        end
      end
    end

    def search_successor(node, _content : String)
      _m_content = M_CONTENT_CHORD_SEARCH_SUCCESSOR.from_json(_content)

      search_successor(node, _m_content.context)
    end

    def search_successor(node, _context : NodeContext)
      if @successor_list.size > 0
        successor = @successor_list[0]
        successor_node_id = NodeID.create_from(successor[:context][:id])

        if @node_id > successor_node_id &&
           (
             @node_id < _context[:id] ||
             successor_node_id > _context[:id]
           )
          send_once(
            _context,
            M_TYPE_CHORD_FOUND_SUCCESSOR,
            {
              context: successor[:context],
            }
          )

          connect_to_successor(node, _context)
        elsif successor_node_id > @node_id &&
              successor_node_id > _context[:id] &&
              @node_id < _context[:id]
          send_once(
            _context,
            M_TYPE_CHORD_FOUND_SUCCESSOR,
            {
              context: successor[:context],
            }
          )

          connect_to_successor(node, _context)
        else
          send_overlay(
            successor[:socket],
            M_TYPE_CHORD_SEARCH_SUCCESSOR,
            {
              context: _context,
            }
          )
        end
      else
        send_once(
          _context,
          M_TYPE_CHORD_FOUND_SUCCESSOR,
          {
            context: context,
          }
        )

        connect_to_successor(node, _context)
      end
    end

    def find_successor? : Node?
      return nil if @successor_list.size == 0

      @successor_list[0]
    end

    def find_predecessor? : Node?
      @predecessor
    end

    def find_nodes : NamedTuple(successor: Node?, private_nodes: Nodes)
      {
        successor:     @successor_list.size > 0 ? @successor_list[0] : nil,
        private_nodes: @private_nodes,
      }
    end

    def connect_to_successor(node, _context : NodeContext)
      info "found new successor: #{_context[:host]}:#{_context[:port]}"

      socket = HTTP::WebSocket.new(_context[:host], "/peer", _context[:port], @use_ssl)

      node.peer(socket)

      spawn do
        socket.run
      end

      if @successor_list.size > 0
        @successor_list[0][:socket].close
        @successor_list[0] = {socket: socket, context: _context}
      else
        @successor_list.push({socket: socket, context: _context})
      end
    end

    def align_successors
      @successor_list = @successor_list.compact

      if @successor_list.size > SUCCESSOR_LIST_SIZE
        removed_successors = @successor_list[SUCCESSOR_LIST_SIZE..-1]
        removed_successors.each do |successor|
          successor[:socket].close
        end

        @successor_list = @successor_list[0..SUCCESSOR_LIST_SIZE - 1]
      end

      if @successor_list.size > 0
        successor = @successor_list[0]

        send_overlay(
          successor[:socket],
          M_TYPE_CHORD_STABILIZE_AS_SUCCESSOR,
          {
            predecessor_context: context,
          }
        )
      end
    end

    def send_once(_context : NodeContext, t : Int32, content)
      send_once(_context[:host], _context[:port], t, content)
    end

    def send_once(connect_host : String, connect_port : Int32, t : Int32, content)
      socket = HTTP::WebSocket.new(connect_host, "/peer", connect_port, @use_ssl)

      send_once(socket, t, content)
    end

    def send_once(socket, t, content)
      send_overlay(socket, t, content)

      socket.close

      clean_connection(socket)
    end

    def send_overlay(socket, t, content)
      send(socket, t, content)
    rescue e : Exception
      clean_connection(socket)
    end

    def ping_all
      @successor_list.each do |successor|
        ping(successor[:socket])
      end

      if predecessor = @predecessor
        ping(predecessor[:socket])
      end
    end

    def ping(socket : HTTP::WebSocket)
      socket.ping
    rescue e : Exception
      clean_connection(socket)
    end

    def clean_connection(socket : HTTP::WebSocket)
      @successor_list.each do |successor|
        if successor[:socket] == socket
          current_successors = @successor_list.size

          @successor_list.delete(successor)

          debug "successor has been removed from successor list."
          debug "#{current_successors} => #{@successor_list.size}"

          break
        end
      end

      if predecessor = @predecessor
        if predecessor[:socket] == socket
          debug "predecessor has been removed"

          @predecessor = nil
        end
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

    include Logger
    include Protocol
    include Consensus
    include Common::Color
  end
end
