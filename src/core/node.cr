require "./node/*"

module ::Sushi::Core
  class Node
    getter id : String
    getter network_type : String

    @blockchain : Blockchain
    @flag : Int32
    @nodes : Models::Nodes
    @miners : Models::Miners

    @rpc_controller : Controllers::RPCController
    @handshake_controller : Controllers::HandshakeController

    @latest_nonces : Array(UInt64)
    @latest_unknown : Int64? = nil

    @cc : Int32 = 0
    @c0 : Int32 = 0
    @c1 : Int32 = 0
    @c2 : Int32 = 0
    @c3 : Int32 = 0

    @connection_salt : String
    @connecting_nodes : Int32 = 0
    @requested_nodes : Int32 = 0

    def initialize(
      @is_private : Bool,
      @is_testnet : Bool,
      @bind_host : String,
      @bind_port : Int32,
      @public_host : String?,
      @public_port : Int32?,
      @ssl : Bool?,
      @connect_host : String?,
      @connect_port : Int32?,
      @wallet : Wallet,
      @database : Database?,
      @conn_min : Int32,
      @use_ssl : Bool = false
    )
      @id = Random::Secure.hex(16)
      @connection_salt = Random::Secure.hex(16)

      info "core version: #{light_green(Core::CORE_VERSION)}"
      info "id: #{light_green(@id)}"

      debug "is_private: #{light_green(@is_private)}"
      debug "public url: #{light_green(@public_host)}:#{light_green(@public_port)}" unless @is_private
      debug "connecting node is using ssl?: #{light_green(@use_ssl)}"

      @blockchain = Blockchain.new(@wallet, @database)
      @network_type = @is_testnet ? "testnet" : "mainnet"
      @nodes = Models::Nodes.new
      @miners = Models::Miners.new
      @flag = FLAG_NONE

      @rpc_controller = Controllers::RPCController.new(@blockchain)
      @handshake_controller = Controllers::HandshakeController.new(@blockchain)
      @latest_nonces = Array(UInt64).new

      wallet_network = Wallet.address_network_type(@wallet.address)

      unless wallet_network[:name] == @network_type
        error "wallet type mismatch"
        error "node's   network: #{@network_type}"
        error "wallet's network: #{wallet_network[:name]}"
        exit -1
      end

      proceed_setup
    end

    private def connect(connect_host : String, connect_port : Int32)
      @connecting_nodes += 1

      info "connecting to #{light_green(connect_host)}:#{light_green(connect_port)} (#{@connecting_nodes})"

      debug "detected an https connecting node - switching to SSL" if @use_ssl

      socket = HTTP::WebSocket.new(connect_host, "/peer", connect_port, @use_ssl)

      peer(socket)

      send(socket, M_TYPE_HANDSHAKE_NODE, {
        version:         Core::CORE_VERSION,
        context:         context,
        connection_salt: @connection_salt,
      })

      connect_async(socket)
    rescue e : Exception
      handle_exception(socket.not_nil!, e, true) if socket

      @connecting_nodes -= 1
      proceed_setup
    end

    private def connect_async(socket)
      spawn do
        socket.run
      rescue e : Exception
        handle_exception(socket, e, true)

        @connecting_nodes -= 1
        proceed_setup
      end
    end

    private def sync_chain(_socket = nil)
      socket = if __socket = _socket
                 __socket
               elsif @nodes.size > 0
                 @nodes.sample[:socket]
               else
                 nil
               end

      if socket
        send(
          socket.not_nil!,
          M_TYPE_REQUEST_CHAIN,
          {latest_index: @latest_unknown ? @latest_unknown.not_nil! - 1 : 0}
        )

        @latest_unknown = nil
      else
        warning "no nodes have been specified, so skip syncking blockchain from other nodes."

        @flag = FLAG_SETUP_PRE_DONE if @flag == FLAG_BLOCKCHAIN_SYNCING
        proceed_setup
      end
    end

    private def draw_routes!
      options "/rpc" do |context|
        context.response.headers["Allow"] = "HEAD,GET,PUT,POST,DELETE,OPTIONS"
        context.response.headers["Access-Control-Allow-Origin"] = "*"
        context.response.headers["Access-Control-Allow-Headers"] =
          "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept"

        context.response.status_code = 200
        context.response.print ""
        context
      end
      post "/rpc" do |context, params|
        context.response.headers["Access-Control-Allow-Origin"] = "*"
        @rpc_controller.exec(context, params)
      end
      get "/handshake/:salt" { |context, params| @handshake_controller.exec(context, params) }
    end

    def run!
      @rpc_controller.set_node(self)
      @handshake_controller.set_node(self)

      draw_routes!

      info "start running Sushi's node on #{light_green(@bind_host)}:#{light_green(@bind_port)}"

      debug "network type: #{light_green(@network_type)}"

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
    end

    private def analytics
      info "recieved block >> total: #{light_cyan(@cc)}, new block: #{light_cyan(@c0)}, " +
           "conflict: #{light_cyan(@c1)}, sync chain: #{light_cyan(@c2)}, older block: #{light_cyan(@c3)}"
    end

    private def _handshake_miner(socket, _content)
      return unless @flag == FLAG_SETUP_DONE

      _m_content = M_CONTENT_HANDSHAKE_MINER.from_json(_content)

      version = _m_content.version
      address = _m_content.address

      if Core::CORE_VERSION > version
        return send(socket,
          M_TYPE_HANDSHAKE_MINER_REJECTED,
          {
            reason: "your sushim is out of date, please update it  (node version: #{Core::CORE_VERSION}, miner version: #{version})",
          })
      end

      miner_network = Wallet.address_network_type(address)[:name]

      if miner_network != @network_type
        warning "mismatch network type with miner #{address}"

        return send(socket, M_TYPE_HANDSHAKE_MINER_REJECTED, {
          reason: "network type mismatch",
        })
      end

      miner = {socket: socket, address: address, nonces: [] of UInt64}

      @miners << miner

      info "new miner: #{light_green(miner[:address])} (#{@miners.size})"

      send(socket, M_TYPE_HANDSHAKE_MINER_ACCEPTED, {
        version:    Core::CORE_VERSION,
        block:      @blockchain.latest_block,
        difficulty: miner_difficulty_at(@blockchain.latest_index),
      })
    end

    private def _handshake_node(socket, _content)
      return unless @flag == FLAG_SETUP_DONE

      _m_content = M_CONTENT_HANDSHAKE_NODE.from_json(_content)

      version = _m_content.version
      node_context = _m_content.context
      connection_salt = _m_content.connection_salt
      connection_hash = sha256(connection_salt + @id)

      if Core::CORE_VERSION > version
        return send(socket,
          M_TYPE_HANDSHAKE_NODE_REJECTED, {
          context: context,
          reason:  "your sushid is out of date, please update it (connecting node: #{Core::CORE_VERSION}, your node: #{version})",
        })
      end

      return warning "node #{node_context[:id]} is already connected" if get_node?(node_context[:id])

      if node_context[:type] != @network_type
        warning "mismatch network type with node #{node_context[:id]}"

        return send(socket, M_TYPE_HANDSHAKE_NODE_REJECTED, {
          context: context,
          reason:  "network type mismatch",
        })
      end

      debug "connection hash as server #{connection_hash}"

      send(socket, M_TYPE_HANDSHAKE_NODE_ACCEPTED, {
        context:         context,
        latest_index:    @blockchain.latest_index,
        connection_hash: connection_hash,
      })

      @nodes << {socket: socket, context: node_context}

      info "new node: #{light_cyan(node_context[:id])} (#{@nodes.size})"
    end

    private def _handshake_node_accepted(socket, _content)
      @connecting_nodes -= 1

      _m_content = M_CONTENT_HANDSHAKE_NODE_ACCEPTED.from_json(_content)

      node_context = _m_content.context
      latest_index = _m_content.latest_index
      connection_hash = _m_content.connection_hash

      debug "connection hash as client #{connection_hash}"

      asserted_connection_hash = http_handshake(node_context)

      if asserted_connection_hash == connection_hash
        @nodes << {socket: socket, context: node_context}
        info "successfully connected: #{node_context[:id]} (#{node_context[:host]}:#{node_context[:port]}) (#{@nodes.size}, #{@connecting_nodes})"
      else
        error "invalid connection hash: expected #{connection_hash} but got #{asserted_connection_hash}"
      end

      proceed_setup
    end

    private def _handshake_node_rejected(socket, _content)
      @connecting_nodes -= 1

      _m_content = M_CONTENT_HANDSHAKE_NODE_REJECTED.from_json(_content)

      node_context = _m_content.context
      reason = _m_content.reason

      error "handshake with #{node_context[:id]} was rejected for the readson;"
      error reason
      error "please check your network type and restart node"

      proceed_setup
    end

    private def _found_nonce(socket, _content)
      return unless @flag == FLAG_SETUP_DONE

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
      return unless @flag == FLAG_SETUP_DONE

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
      return unless @flag == FLAG_SETUP_DONE

      _m_content = M_CONTENT_BROADCAST_BLOCK.from_json(_content)

      block = _m_content.block
      known_nodes = _m_content.known_nodes

      @cc += 1

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
      return unless @flag == FLAG_SETUP_DONE

      _m_content = M_CONTENT_REQUEST_CHAIN.from_json(_content)

      latest_index = _m_content.latest_index

      info "requested new chain: #{latest_index}"

      send(socket, M_TYPE_RECIEVE_CHAIN, {chain: @blockchain.subchain(latest_index + 1)})
    end

    private def _recieve_chain(socket, _content)
      _m_content = M_CONTENT_RECIEVE_CHAIN.from_json(_content)

      chain = _m_content.chain

      if _chain = chain
        info "recieved chain's size: #{_chain.size}"
      else
        info "recieved empty chain."
      end

      current_latest_index = @blockchain.latest_index

      if @blockchain.replace_chain(chain)
        info "chain updated: #{light_green(current_latest_index)} -> #{light_green(@blockchain.latest_index)}"
        broadcast_to_miners
      end

      @flag = FLAG_SETUP_PRE_DONE if @flag == FLAG_BLOCKCHAIN_SYNCING
      proceed_setup
    end

    private def _request_nodes(socket, _content)
      return unless @flag == FLAG_SETUP_DONE

      _m_content = M_CONTENT_REQUEST_NODES.from_json(_content)

      _known_nodes = _m_content.known_nodes
      request_nodes_num = _m_content.request_nodes_num

      node_list_all = @nodes.map { |n|
        (
          n[:context][:id] == @id ||
          n[:context][:is_private] ||
          _known_nodes.includes?(n[:context])
        ) ? nil : n[:context]
      }.compact

      node_list = if node_list_all.size == 0
                    [] of Models::NodeContext
                  else
                    node_list_all.sample(request_nodes_num)
                  end

      send(socket, M_TYPE_RECIEVE_NODES, {node_list: node_list})
    end

    private def _recieve_nodes(socket, _content)
      _m_content = M_CONTENT_RECIEVE_NODES.from_json(_content)

      node_contexts = @nodes.map { |node| node[:context] }

      node_list = _m_content.node_list
      node_list.reject! { |nc| node_contexts.includes?(nc) }

      info "recieved new nodes (#{node_list.size})"

      if node_list.size > 0
        connect_node = node_list.sample
        connect(connect_node[:host], connect_node[:port])
      end

      proceed_setup
    end

    private def reject!(socket : HTTP::WebSocket, _e : Exception?)
      if reject_node?(socket)
        info "a node has been removed. (#{@nodes.size})"
      end

      info "a miner has been removed. (#{@miners.size})" if reject_miner?(socket)

      if e = _e
        if error_message = e.message
          error error_message
        end
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
        ssl:        @ssl || false,
        type:       @network_type,
        is_private: @is_private,
      }
    end

    private def known_nodes : Models::NodeContexts
      _known_nodes = @nodes.map { |node| node[:context] }
      _known_nodes << context
      _known_nodes
    end

    private def proceed_setup
      return if @flag == FLAG_SETUP_DONE

      case @flag
      when FLAG_NONE
        if @connect_host && @connect_port
          @flag = FLAG_CONNECTING_NODES

          connect(@connect_host.not_nil!, @connect_port.not_nil!)
        else
          warning "no connecting node has been specified"
          warning "so this node is standalone from other network"

          @flag = FLAG_BLOCKCHAIN_LOADING

          proceed_setup
        end
      when FLAG_CONNECTING_NODES
        debug "connecting nodes... (#{@connecting_nodes})"

        if @connecting_nodes == 0
          if @nodes.size >= @conn_min
            @flag = FLAG_BLOCKCHAIN_LOADING
            proceed_setup
          elsif @requested_nodes < 3 && @nodes.size > 0
              @requested_nodes += 1

              socket = @nodes.sample[:socket]

              info "current connection (#{@nodes.size}) is less than the min connection (#{@conn_min})."
              info "requesting new nodes (#{@conn_min - @nodes.size}) (#{@requested_nodes})"

              send(socket, M_TYPE_REQUEST_NODES, {
                     known_nodes:       known_nodes,
                     request_nodes_num: @conn_min - @nodes.size,
                   })
          else
            warning "the connection number (#{@nodes.size}) might be less then the min connection (#{@conn_min})."
            warning "but we proceed the setup since there might be not enough nodes."

            @flag = FLAG_BLOCKCHAIN_LOADING
            proceed_setup
          end
        end
      when FLAG_BLOCKCHAIN_LOADING
        @blockchain.setup(self)

        info "loaded blockchain's size: #{light_cyan(@blockchain.chain.size)}"

        if @database
          @latest_unknown = @blockchain.latest_index + 1
        else
          warning "no database has been specified"
        end

        @flag = FLAG_BLOCKCHAIN_SYNCING

        proceed_setup
      when FLAG_BLOCKCHAIN_SYNCING
        sync_chain
      when FLAG_SETUP_PRE_DONE
        info "successfully setup the node."
        @flag = FLAG_SETUP_DONE
      end
    end

    private def http_handshake(context : Models::NodeContext) : String
      res = HTTP::Client.get(
        "#{context[:ssl] ? "https" : "http"}://#{context[:host]}:#{context[:port]}/handshake/#{@connection_salt}"
      )
      res.body
    end

    include Logger
    include Router
    include Protocol
    include Consensus
    include Common::Color
  end
end
