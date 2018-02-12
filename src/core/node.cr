require "./node/*"

module ::Sushi::Core
  class Node
    @blockchain : Blockchain
    @network_type : String
    @id : String
    @nodes : Models::Nodes
    @miners : Models::Miners
    @rpc_controller : Controllers::RPCController

    @latest_nonces : Array(UInt64)
    @latest_unknown : Int64? = nil

    @cc : Int32 = 0
    @c0 : Int32 = 0
    @c1 : Int32 = 0
    @c2 : Int32 = 0
    @c3 : Int32 = 0

    @flag = FLAG_NONE

    def initialize(
      @is_private : Bool,
      @is_testnet : Bool,
      @bind_host : String,
      @bind_port : Int32,
      @public_host : String?,
      @public_port : Int32?,
      connect_host : String?,
      connect_port : Int32?,
      @wallet : Wallet,
      @database : Database?,
      @max_connection : Int32
    )
      @id = Random::Secure.hex(16)

      info "id: #{light_green(@id)}"
      info "is_private: #{light_green(@is_private)}"
      info "public url: #{light_green(@public_host)}:#{light_green(@public_port)}" unless @is_private

      @blockchain = Blockchain.new(@wallet, @database)

      info "loaded blockchain's size: #{light_cyan(@blockchain.chain.size)}"

      if @database
        @latest_unknown = @blockchain.latest_index + 1
      else
        warning "no database has been specified"
      end

      @network_type = @is_testnet ? "testnet" : "mainnet"
      @nodes = Models::Nodes.new
      @miners = Models::Miners.new
      @flag = 0_u8
      @rpc_controller = Controllers::RPCController.new(@blockchain)
      @latest_nonces = Array(UInt64).new

      wallet_network = Wallet.address_network_type(@wallet.address)

      unless wallet_network[:name] == @network_type
        error "wallet type mismatch"
        error "node's   network: #{@network_type}"
        error "wallet's network: #{wallet_network[:name]}"
        exit -1
      end

      if connect_host && connect_port
        connect(connect_host.not_nil!, connect_port.not_nil!) # , @max_connection - 1)
      else
        warning "no connecting node has been specified"
        warning "so this node is standalone from other network"
      end
    end

    private def connect(connect_host : String, connect_port : Int32) # , request_nodes_num : Int32 = 0)
      info "connecting to #{light_green(connect_host)}:#{light_green(connect_port)}"

      # known_nodes = @nodes.map { |n| n[:context] }

      socket = HTTP::WebSocket.new(connect_host, "/peer", connect_port)

      peer(socket)

      send(socket, M_TYPE_HANDSHAKE_NODE, {context: context})# , known_nodes: known_nodes, request_nodes_num: request_nodes_num})

      connect_async(socket)
    rescue e : Exception
      handle_exception(socket.not_nil!, e, true) if socket
    end

    private def connect_async(socket)
      spawn do
        socket.run
      rescue e : Exception
        handle_exception(socket, e, true)
      end
    end

    private def draw_routes!
      post "/rpc" { |context, params| @rpc_controller.exec(context, params) }
    end

    def run!
      @rpc_controller.set_node(self)

      draw_routes!

      info "start running Sushi's node on #{light_green(@bind_host)}:#{light_green(@bind_port)}"
      info "network type: #{light_green(@network_type)}"

      node = HTTP::Server.new(@bind_host, @bind_port, handlers)
      node.listen
    end

    private def peer_handler : WebSocketHandler
      WebSocketHandler.new("/peer") { |socket, context| peer(socket) }
    end

    private def peer(socket : HTTP::WebSocket)
      socket.on_message do |message|
        message_json = JSON.parse(message)
        message_type = message_json["type"].as_i
        message_content = message_json["content"].to_s

        case message_type
        when M_TYPE_HANDSHAKE_MINER
          _handshake_miner(socket, message_content)
        when M_TYPE_HANDSHAKE_NODE
          _handshake_node(socket, message_content)
        when M_TYPE_HANDSHAKE_NODE_ACCEPTED
          _handshake_node_accepted(socket, message_content)
        when M_TYPE_HANDSHAKE_NODE_REJECTED
          _handshake_node_rejected(socket, message_content)
        when M_TYPE_FOUND_NONCE
          _found_nonce(socket, message_content)
        when M_TYPE_BROADCAST_TRANSACTION
          _broadcast_transaction(socket, message_content)
        when M_TYPE_BROADCAST_BLOCK
          _broadcast_block(socket, message_content)
        when M_TYPE_REQUEST_CHAIN
          _request_chain(socket, message_content)
        when M_TYPE_RECIEVE_CHAIN
          _recieve_chain(socket, message_content)
        when M_TYPE_REQUEST_NODES
          _request_nodes(socket, message_content)
        when M_TYPE_RECIEVE_NODES
          _recieve_nodes(socket, message_content)
        end
      rescue e : Exception
        handle_exception(socket, e)
      end

      socket.on_close do |_|
        reject!(socket, nil)
      end
    rescue e : Exception
      handle_exception(socket, e)
    end

    def broadcast_transaction(transaction : Transaction)
      info "new transaction coming: #{transaction.id}"

      @blockchain.add_transaction(transaction)

      @nodes.each do |node|
        send(node[:socket], M_TYPE_BROADCAST_TRANSACTION, {
          transaction: transaction,
          known_nodes: known_nodes,
        })
      end
    end

    private def handle_exception(socket : HTTP::WebSocket, e : Exception, reject_node : Bool = false)
      if error_message = e.message
        error error_message
      else
        error "unknown error"
      end

      if node = get_node?(socket)
        error "on: #{node[:context][:host]}:#{node[:context][:port]}"
      end

      if reject_node
        error "remove the connection from the pool"
        reject!(socket, nil)
      end

      @flag = 0
    end

    private def sync_chain(socket)
      flag_set(FLAG_BLOCKCHAIN_SYNCING)

      if latest_unknown = @latest_unknown
        send(socket, M_TYPE_REQUEST_CHAIN, {latest_index: latest_unknown - 1})
        @latest_unknown = nil
      else
        send(socket, M_TYPE_REQUEST_CHAIN, {latest_index: 0})
      end
    end

    private def analytics
      info "recieved block >> total: #{light_cyan(@cc)}, new block: #{light_cyan(@c0)}, " +
           "conflict: #{light_cyan(@c1)}, sync chain: #{light_cyan(@c2)}, older block: #{light_cyan(@c3)}"
    end

    private def _handshake_miner(socket, _content)
      return if flag_get?(FLAG_BLOCKCHAIN_SYNCING)

      _m_content = M_CONTENT_HANDSHAKE_MINER.from_json(_content)
      address = _m_content.address
      miner_network = Wallet.address_network_type(address)[:name]

      if miner_network != @network_type
        warning "mismatch network type with miner #{address}"

        return send(socket, M_TYPE_HANDSHAKE_MINER_REJECTED, {
          reason: "Network type mismatch",
        })
      end

      miner = {socket: socket, address: address, nonces: [] of UInt64}

      @miners << miner

      info "new miner: #{light_green(miner[:address])} (#{@miners.size})"

      send(socket, M_TYPE_HANDSHAKE_MINER_ACCEPTED, {
        block:      @blockchain.latest_block,
        difficulty: miner_difficulty_at(@blockchain.latest_index),
      })
    end

    private def _handshake_node(socket, _content)
      return if flag_get?(FLAG_BLOCKCHAIN_SYNCING) || flag_get?(FLAG_REQUESTING_NODES)

      _m_content = M_CONTENT_HANDSHAKE_NODE.from_json(_content)

      node_context = _m_content.context
      # known_nodes = _m_content.known_nodes
      # request_nodes_num = _m_content.request_nodes_num

      return warning "node #{node_context[:id]} is already connected" if get_node?(node_context[:id])

      if node_context[:type] != @network_type
        warning "mismatch network type with node #{node_context[:id]}"

        return send(socket, M_TYPE_HANDSHAKE_NODE_REJECTED, {
          context: context,
          reason:  "Network type mismatch",
        })
      end

      # node_list = @nodes.map { |n|
      #   (n[:context][:id] == @id || n[:context][:is_private] || known_nodes.includes?(n[:context])) ? nil : n[:context]
      # }.compact.sample(request_nodes_num)

      send(socket, M_TYPE_HANDSHAKE_NODE_ACCEPTED, {
        context:      context,
        # node_list:    node_list,
        latest_index: @blockchain.latest_index,
      })

      @nodes << {socket: socket, context: node_context}

      info "new node: #{light_cyan(node_context[:id])} (#{@nodes.size})"
    end

    private def _handshake_node_accepted(socket, _content)
      _m_content = M_CONTENT_HANDSHAKE_NODE_ACCEPTED.from_json(_content)

      node_context = _m_content.context
      # node_list = _m_content.node_list
      latest_index = _m_content.latest_index

      @nodes << {socket: socket, context: node_context}

      info "successfully connected: #{node_context[:id]} (#{@nodes.size})"

      # node_list.each { |nc| connect(nc[:host], nc[:port]) }

      if @nodes.size < @max_connection && !flag_get?(FLAG_REQUESTING_NODES)
        flag_set(FLAG_REQUESTING_NODES)

        info "current connection (#{@nodes.size}) is less than the min connection (#{@max_connection})."
        info "requesting new nodes (#{@max_connection - @nodes.size})"

        send(socket, M_TYPE_REQUEST_NODES, {
               known_nodes: known_nodes,
               request_nodes_num: @max_connection - @nodes.size,
             })
      end

      sync_chain(socket) if latest_index > @blockchain.latest_index && !flag_get?(FLAG_BLOCKCHAIN_SYNCING)
    end

    private def _handshake_node_rejected(socket, _content)
      _m_content = M_CONTENT_HANDSHAKE_NODE_REJECTED.from_json(_content)

      node_context = _m_content.context
      reason = _m_content.reason

      error "handshake with #{node_context[:id]} was rejected for the readson;"
      error reason
      error "please check your network type and restart node"
    end

    private def _found_nonce(socket, _content)
      return if flag_get?(FLAG_BLOCKCHAIN_SYNCING)

      _m_content = M_CONTENT_FOUND_NONCE.from_json(_content)

      nonce = _m_content.nonce

      if miner = get_miner?(socket)
        if !@latest_nonces.includes?(nonce) &&
           @blockchain.latest_block.valid_nonce?(nonce, miner_difficulty_at(@blockchain.latest_block.index))
          miner[:nonces].push(nonce)
          @latest_nonces.push(nonce)

          info "miner #{miner[:address]} found nonce (#{miner[:nonces].size})"
        else
          warning "nonce #{nonce} has already been discoverd" if @latest_nonces.includes?(nonce)

          if !@blockchain.latest_block.valid_nonce?(nonce, miner_difficulty_at(@blockchain.latest_block.index))
            warning "recieved nonce is invalid, try to update latest block"

            send(miner[:socket], M_TYPE_BLOCK_UPDATE, {
              block:      @blockchain.latest_block,
              difficulty: miner_difficulty_at(@blockchain.latest_index),
            })
          end
        end
      end

      return unless block = @blockchain.push_block?(nonce, @miners)

      info "found new nonce: #{light_green(nonce)} (#{@blockchain.latest_index})"

      known_nodes = @nodes.map { |node| node[:context] }
      known_nodes << context

      @nodes.each do |n|
        send(n[:socket], M_TYPE_BROADCAST_BLOCK, {block: block, known_nodes: known_nodes})
      end

      @miners.each do |m|
        m[:nonces].clear
      end

      @latest_nonces.clear

      broadcast_to_miners
    end

    private def _broadcast_transaction(socket, _content)
      return if flag_get?(FLAG_BLOCKCHAIN_SYNCING)

      _m_content = M_CONTENT_BROADCAST_TRANSACTION.from_json(_content)

      transaction = _m_content.transaction
      _known_nodes = _m_content.known_nodes

      raw_transaction = transaction.dup

      info "new transaction coming: #{transaction.id}"

      @blockchain.add_transaction(transaction)

      other_known_nodes = @nodes.reject { |node| _known_nodes.includes?(node[:context]) }

      _known_nodes.concat(other_known_nodes.map { |node| node[:context] })

      other_known_nodes.each do |node|
        send(node[:socket], M_TYPE_BROADCAST_TRANSACTION, {
          transaction: raw_transaction,
          known_nodes: _known_nodes,
        })
      end
    end

    private def _broadcast_block(socket, _content)
      _m_content = M_CONTENT_BROADCAST_BLOCK.from_json(_content)

      block = _m_content.block
      known_nodes = _m_content.known_nodes

      @cc += 1

      return analytics if flag_get?(FLAG_BLOCKCHAIN_SYNCING)

      if @blockchain.latest_index + 1 == block.index
        @c0 += 1

        unless @blockchain.push_block?(block, @miners)
          if node = get_node?(socket)
            error "pushed block is invalid coming from #{node[:context][:host]}:#{node[:context][:port]}"
          end

          return analytics
        end

        info "new block coming: #{light_cyan(@blockchain.chain.size)}"

        other_known_nodes = @nodes.reject { |node| known_nodes.includes?(node[:context]) }

        known_nodes.concat(other_known_nodes.map { |node| node[:context] })

        other_known_nodes.each do |node|
          send(node[:socket], M_TYPE_BROADCAST_BLOCK, {block: block, known_nodes: known_nodes})
        end

        broadcast_to_miners
      elsif @blockchain.latest_index == block.index
        @c1 += 1

        if node = get_node?(socket)
          warning "blockchain conflicted with #{node[:context][:host]}:#{node[:context][:port]}"
          warning "ignore the block. (#{light_cyan(@blockchain.chain.size)})"

          @latest_unknown ||= block.index
        end
      elsif @blockchain.latest_index + 1 < block.index
        @c2 += 1

        warning "required new chain: #{@blockchain.latest_block.index} for #{block.index}"

        sync_chain(socket)
      else
        @c3 += 1

        warning "recieved old block, will be ignored"
      end

      analytics
    end

    private def _request_chain(socket, _content)
      _m_content = M_CONTENT_REQUEST_CHAIN.from_json(_content)

      latest_index = _m_content.latest_index

      info "requested new chain: #{latest_index}"

      send(socket, M_TYPE_RECIEVE_CHAIN, {chain: @blockchain.subchain(latest_index + 1)})
    end

    private def _recieve_chain(socket, _content)
      _m_content = M_CONTENT_RECIEVE_CHAIN.from_json(_content)

      chain = _m_content.chain

      info "recieved chain's size: #{chain.size}"

      current_latest_index = @blockchain.latest_index

      if @blockchain.replace_chain(chain)
        info "chain updated: #{current_latest_index} -> #{@blockchain.latest_index}"
        flag_unset(FLAG_BLOCKCHAIN_SYNCING)

        broadcast_to_miners
      else
        error "error while syncing chain, retrying..."
        sync_chain(socket)
      end
    end

    private def _request_nodes(socket, _content)
      _m_content = M_CONTENT_REQUEST_NODES.from_json(_content)

      _known_nodes = _m_content.known_nodes
      request_nodes_num = _m_content.request_nodes_num

      node_list = @nodes.map { |n|
        (n[:context][:id] == @id || n[:context][:is_private] || _known_nodes.includes?(n[:context])) ? nil : n[:context]
      }.compact.sample(request_nodes_num)

      send(socket, M_TYPE_RECIEVE_NODES, {node_list: node_list})
    end

    private def _recieve_nodes(socket, _content)
      _m_content = M_CONTENT_RECIEVE_NODES.from_json(_content)

      flag_unset(FLAG_REQUESTING_NODES)

      node_list = _m_content.node_list
      node_list.each { |nc| connect(nc[:host], nc[:port]) }
    end

    private def reject!(socket : HTTP::WebSocket, _e : Exception?)
      info "a node has been removed. (#{@nodes.size})" if reject_node?(socket)
      info "a miner has been removed. (#{@miners.size})" if reject_miner?(socket)

      return unless e = _e

      if error_message = e.message
        error error_message
      end
    end

    private def reject_node?(socket : HTTP::WebSocket)
      nodes_size = @nodes.size
      @nodes.reject! { |node| node[:socket] == socket }
      nodes_size != @nodes.size
    end

    private def reject_miner?(socket : HTTP::WebSocket)
      miners_size = @miners.size
      @miners.reject! { |miner| miner[:socket] == socket }
      miners_size != @miners.size
    end

    private def broadcast_to_miners
      info "broadcast a block to miners"

      @miners.each do |miner|
        send(miner[:socket], M_TYPE_BLOCK_UPDATE, {
          block:      @blockchain.latest_block,
          difficulty: miner_difficulty_at(@blockchain.latest_index),
        })
      end
    end

    private def get_node?(socket : HTTP::WebSocket) : Models::Node?
      node = @nodes.find { |n| n[:socket] == socket }
    end

    private def get_node?(id : String) : Models::Node?
      node = @nodes.find { |n| n[:context][:id] == id }
    end

    private def get_miner?(socket) : Models::Miner?
      miner = @miners.find { |m| m[:socket] == socket }
    end

    private def handlers
      [
        peer_handler,
        route_handler,
      ]
    end

    private def context : Models::NodeContext
      {
        id:         @id,
        host:       @public_host || "",
        port:       @public_port || -1,
        type:       @network_type,
        is_private: @is_private,
      }
    end

    private def known_nodes : Models::NodeContexts
      _known_nodes = @nodes.map { |node| node[:context] }
      _known_nodes << context
      _known_nodes
    end

    private def flag_set(new_flag)
      @flag = @flag | new_flag
    end

    private def flag_unset(new_flag)
      @flag = @flag & ~new_flag
    end

    private def flag_get?(flag) : Bool
      (@flag & flag) == flag
    end

    include Logger
    include Router
    include Protocol
    include Consensus
    include Common::Color
  end
end
