# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "./node_id"

module ::Axentro::Core::NodeComponents
  class Chord < HandleSocket
    SUCCESSOR_LIST_SIZE = 3

    alias NodeContext = NamedTuple(
      id: String,
      host: String,
      port: Int32,
      ssl: Bool,
      type: String,
      is_private: Bool,
      address: String)

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
    @finger_table : Set(NodeContext) = Set.new([] of NodeContext)

    @show_network = 0

    def initialize(
      @public_host : String?,
      @public_port : Int32?,
      @ssl : Bool?,
      @network_type : String,
      @is_private : Bool,
      @use_ssl : Bool,
      @max_private_nodes : Int32,
      @wallet_address : String,
      @official_node : DApps::BuildIn::OfficialNode,
      @exit_if_unofficial : Bool
    )
      @node_id = NodeID.new

      info "node id: #{light_green(@node_id.to_s)}"

      stabilize_process
      check_for_official_nodes
    end

    def all_node_contexts
      contexts = Set.new(@successor_list.map { |s| s[:context] })
      if predecessor = @predecessor
        contexts.add(predecessor[:context])
      end
      contexts.add(context)
      contexts.to_a
    end

    def add_to_finger_table(joined_nodes)
      joined_nodes.each { |n| @finger_table.add(n) }
    end

    def clean_finger_table
      @finger_table.clear
    end

    def join_to(node, connect_host : String, connect_port : Int32)
      debug "joining network: #{connect_host}:#{connect_port}"

      send_once(
        connect_host,
        connect_port,
        M_TYPE_CHORD_JOIN,
        {
          version: Core::CORE_VERSION,
          context: context,
        })
    rescue e : Exception
      error "failed to connect #{connect_host}:#{connect_port}"
      error "please specify another public host if you need a successor"

      node.phase = SetupPhase::PRE_DONE
      node.proceed_setup
    end

    def join_to_private(node, connect_host : String, connect_port : Int32)
      debug "joining network: #{connect_host}:#{connect_port} (private)"

      socket = HTTP::WebSocket.new(connect_host, "/peer", connect_port, @use_ssl)

      node.peer(socket)

      spawn do
        socket.run
      rescue e : Exception
        handle_exception(socket, e)
      end

      send(
        socket,
        M_TYPE_CHORD_JOIN_PRIVATE,
        {
          version: Core::CORE_VERSION,
          context: context,
        }
      )
    rescue e : Exception
      error "failed to connect #{connect_host}:#{connect_port}"
      error "please specify another public host if you need a successor"

      node.phase = SetupPhase::PRE_DONE
      node.proceed_setup
    end

    def join(node, socket, _content)
      _m_content = MContentChordJoin.from_json(_content)

      _context = _m_content.context

      debug "#{_context[:host]}:#{_context[:port]} try to join Axentro"

      if _context[:type] != @network_type
        send_once(_context, M_TYPE_CHORD_JOIN_REJECTED, {reason: "network type mismatch. " +
                                                                 "your network: #{_context[:type]}, our network: #{@network_type}"})
        return
      end

      search_successor(node, _context)
    end

    def join_private(node, socket, _content)
      _m_content = MContentChordJoinPrivate.from_json(_content)

      _context = _m_content.context

      debug "private node trying to join Axentro"

      if @private_nodes.size >= @max_private_nodes
        send(socket, M_TYPE_CHORD_JOIN_REJECTED, {reason: "The max private node connections of #{@max_private_nodes} for this node has been reached"})
        return
      end

      if _context[:type] != @network_type
        send(socket, M_TYPE_CHORD_JOIN_REJECTED, {reason: "network type mismatch. " +
                                                          "your network: #{_context[:type]}, our network: #{@network_type}"})
        return
      end

      @private_nodes << {
        socket:  socket,
        context: _context,
      }
      send(socket, M_TYPE_CHORD_JOIN_PRIVATE_ACCEPTED, {context: context})
    end

    def join_private_accepted(node, socket, _content)
      _m_content = MContentChordJoinPrivateAccepted.from_json(_content)

      _context = _m_content.context

      debug "successfully joined the network"

      @successor_list.push({
        socket:  socket,
        context: _context,
      })

      @predecessor = {socket: socket, context: _context}

      node.phase = SetupPhase::BLOCKCHAIN_SYNCING
      node.proceed_setup
    end

    def join_rejected(node, socket, _content)
      _m_content = MContentChordJoinRejected.from_json(_content)

      _reason = _m_content.reason

      error "attempt to join the network was rejected."
      error "the reason: #{_reason}"
      error "the node will be exited with -1."

      exit -1
    end

    def found_successor(node, _content : String)
      _m_content = MContentChordFoundSuccessor.from_json(_content)
      _context = _m_content.context

      connect_to_successor(node, _context)

      node.phase = SetupPhase::BLOCKCHAIN_SYNCING
      node.proceed_setup
    end

    def stabilize_as_successor(node, socket, _content : String)
      _m_content = MContentChordStabilizeAsSuccessor.from_json(_content)

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
      _m_content = MContentChordStabilizeAsPredecessor.from_json(_content)

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
      node.send_nodes_joined(all_node_contexts)
    end

    def table_line(col0 : String, col1 : String, delimiter = "|")
      verbose "#{delimiter} %20s #{delimiter} %20s #{delimiter}" % [col0, col1]
    end

    def stabilize_process
      spawn do
        now = Time.local
        loop do
          sleep Random.rand

          if (@show_network += 1) % 20 == 0
            table_line("-" * 20, "-" * 20, "+")

            if @successor_list.size > 0
              @successor_list.each_with_index do |successor, i|
                table_line "successor (#{i})",
                  "#{successor[:context][:host]}:#{successor[:context][:port]}"
              end
            else
              table_line "successor", "Not found"
            end

            if predecessor = @predecessor
              table_line "predecessor",
                "#{predecessor[:context][:host]}:#{predecessor[:context][:port]}"
            else
              table_line "predecessor", "Not found"
            end

            if @private_nodes.size > 0
              table_line "private nodes", @private_nodes.size.to_s
            end

            table_line("-" * 20, "-" * 20, "+")
          end

          ping_all

          align_successors

          stabilise_finger_table

          if (Time.local - now) >= 8.seconds
            check_for_official_nodes
            now = Time.local
          end
        end
      end
    end

    private def check_for_official_nodes
      node_list = @official_node.all_impl

      if @finger_table.size > 0 && !is_only_this_node
        if (node_list & @finger_table.map { |n| n[:address] }).empty?
          warning "This node is #{red("NOT connected")} to an official network"
          if @exit_if_unofficial
            warning "This node is configured to terminate if not connected to an official network - terminating now"
            exit -1
          end
        else
          verbose "This node is connected to an official network"
        end
      end
    end

    private def is_only_this_node
      @finger_table.size == 1 && @finger_table.map { |n| n[:address] }.first == @wallet_address
    end

    def search_successor(node, _content : String)
      _m_content = MContentChordSearchSuccessor.from_json(_content)

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
      if _context[:is_private]
        error "the connecting node is private"
        error "please specify a public node as connecting node"
        error "exit with -1"
        exit -1
      end

      info "found new successor: #{_context[:host]}:#{_context[:port]}"

      socket = HTTP::WebSocket.new(_context[:host], "/peer", _context[:port], @use_ssl)

      node.peer(socket)

      spawn do
        socket.run
      rescue e : Exception
        handle_exception(socket, e)
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

        unless @is_private
          send_overlay(
            successor[:socket],
            M_TYPE_CHORD_STABILIZE_AS_SUCCESSOR,
            {
              predecessor_context: context,
            }
          )
        end
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
    end

    def ping_all
      @successor_list.each do |successor|
        ping(successor[:socket])
      end

      if predecessor = @predecessor
        ping(predecessor[:socket])
      end
    end

    def stabilise_finger_table
      sockets = [] of HTTP::WebSocket
      @finger_table.each do |ctx|
        debug "stabilize finger table: #{ctx[:host]}:#{ctx[:port]}}"
        socket = HTTP::WebSocket.new(ctx[:host], "/peer", ctx[:port], ctx[:ssl])
        sockets << socket
        socket.ping
      rescue i : IO::Error
        @finger_table.delete(ctx)
      end
      sockets.each { |s| s.close }
    rescue i : IO::Error
      stabilise_finger_table
    end

    def ping(socket : HTTP::WebSocket)
      socket.ping
    rescue i : IO::Error
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

      @private_nodes.each do |private_node|
        if private_node[:socket] == socket
          @private_nodes.delete(private_node)
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
        address:    @wallet_address,
      }
    end

    def connected_nodes
      {
        successor_list: extract_context(@successor_list),
        predecessor:    extract_context(@predecessor),
        private_nodes:  extract_context(@private_nodes),
        finger_table:   @finger_table,
      }
    end

    def extract_context(nodes : Nodes) : NodeContexts
      nodes.map { |n| extract_context(n) }
    end

    def extract_context(node : Node) : NodeContext
      node[:context]
    end

    def extract_context(node : Nil) : Nil
      nil
    end

    def find_node(id : String) : NodeContext
      return context if context[:id] == id

      (@finger_table.to_a + @private_nodes.map { |n| extract_context(n) }).each do |ctx|
        return ctx if ctx[:id] == id
      end

      raise "the node #{id} not found. (only searching nodes which are currently connected.)"
    end

    def find_node_by_address(address : String) : Array(NodeContext)
      list = @finger_table.to_a + @private_nodes.map { |n| extract_context(n) }
      list = list << context
      result = list.select { |ctx| ctx[:address] == address }

      raise "the node with address #{address} not found. (only searching nodes which are currently connected.)" if result.empty?
      result.uniq
    end

    def official_nodes_list
      {
        all:    @official_node.all_impl,
        online: online_official_nodes,
      }
    end

    private def online_official_nodes
      list = @finger_table << context
      list = list.select { |ctx| @official_node.all_impl.includes?(ctx[:address]) }
      list.map do |ctx| 
        transport = ctx[:ssl] ? "https://" : "http://"
        {id: ctx[:id], address: ctx[:address], url: "#{transport}#{ctx[:host]}:#{ctx[:port]}"} 
      end
    end

    include Protocol
    include Consensus
    include Common::Color
  end
end
