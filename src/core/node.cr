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

require "./node/*"

module ::Sushi::Core
  class Node
    alias Network = NamedTuple(
      prefix: String,
      name: String,
    )

    property flag : Int32

    getter network_type : String

    @blockchain : Blockchain
    @miners_manager : MinersManager
    @chord : Chord

    @rpc_controller : Controllers::RPCController

    # todo
    @last_conflicted : Int64 = 0_i64

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
      @use_ssl : Bool = false
    )
      @blockchain = Blockchain.new(@wallet, @database)
      @network_type = @is_testnet ? "testnet" : "mainnet"
      @chord = Chord.new(@public_host, @public_port, @ssl, @network_type, @is_private, @use_ssl)
      @miners_manager = MinersManager.new
      @flag = FLAG_NONE

      info "core version: #{light_green(Core::CORE_VERSION)}"

      debug "is_private: #{light_green(@is_private)}"
      debug "public url: #{light_green(@public_host)}:#{light_green(@public_port)}" unless @is_private
      debug "connecting node is using ssl?: #{light_green(@use_ssl)}"
      debug "network type: #{light_green(@network_type)}"

      @rpc_controller = Controllers::RPCController.new(@blockchain)

      wallet_network = Wallet.address_network_type(@wallet.address)

      unless wallet_network[:name] == @network_type
        error "wallet type mismatch"
        error "node's   network: #{@network_type}"
        error "wallet's network: #{wallet_network[:name]}"
        exit -1
      end

      spawn proceed_setup
    end

    def run!
      @rpc_controller.set_node(self)

      draw_routes!

      info "start running Sushi's node on #{light_green(@bind_host)}:#{light_green(@bind_port)}"

      node = HTTP::Server.new(@bind_host, @bind_port, handlers)
      node.listen
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
    end

    private def sync_chain(socket : HTTP::WebSocket? = nil)
      info "start synching blockchain."

      s = if _socket = socket
            _socket
          elsif predecessor = @chord.find_predecessor?
            predecessor[:socket]
          elsif successor = @chord.find_successor?
            successor[:socket]
          end

      if _s = s
        begin
          send(
            _s,
            M_TYPE_NODE_REQUEST_CHAIN,
            {
              latest_index: @last_conflicted,
            }
          )
        rescue e : Exception
          handle_exception(_s, e)
        end
      else
        warning "successor not found. skip synching blockchain."

        if @flag == FLAG_BLOCKCHAIN_SYNCING
          @flag = FLAG_SETUP_PRE_DONE
          proceed_setup
        end
      end
    end

    private def peer_handler : WebSocketHandler
      WebSocketHandler.new("/peer") { |socket, context| peer(socket) }
    end

    def peer(socket : HTTP::WebSocket)
      socket.on_message do |message|
        message_json = JSON.parse(message)
        message_type = message_json["type"].as_i
        message_content = message_json["content"].to_s

        case message_type
        when M_TYPE_MINER_HANDSHAKE
          @miners_manager.handshake(self, @blockchain, socket, message_content)
        when M_TYPE_MINER_FOUND_NONCE
          @miners_manager.found_nonce(self, @blockchain, socket, message_content)
        when M_TYPE_CHORD_JOIN
          @chord.join(self, socket, message_content)
        when M_TYPE_CHORD_JOIN_PRIVATE
          @chord.join_private(self, socket, message_content)
        when M_TYPE_CHORD_JOIN_PRIVATE_ACCEPTED
          @chord.join_private_accepted(self, socket, message_content)
        when M_TYPE_CHORD_JOIN_REJECTED
          @chord.join_rejected(self, socket, message_content)
        when M_TYPE_CHORD_SEARCH_SUCCESSOR
          @chord.search_successor(self, message_content)
        when M_TYPE_CHORD_FOUND_SUCCESSOR
          @chord.found_successor(self, message_content)
        when M_TYPE_CHORD_STABILIZE_AS_SUCCESSOR
          @chord.stabilize_as_successor(self, socket, message_content)
        when M_TYPE_CHORD_STABILIZE_AS_PREDECESSOR
          @chord.stabilize_as_predecessor(self, socket, message_content)
        when M_TYPE_NODE_REQUEST_CHAIN
          _request_chain(socket, message_content)
        when M_TYPE_NODE_RECEIVE_CHAIN
          _receive_chain(socket, message_content)
        when M_TYPE_NODE_BROADCAST_TRANSACTION
          _broadcast_transaction(socket, message_content)
        when M_TYPE_NODE_BROADCAST_BLOCK
          _broadcast_block(socket, message_content)
        when M_TYPE_NODE_ASK_REQUEST_CHAIN
          _ask_request_chain(socket, message_content)
        end
      rescue e : Exception
        handle_exception(socket, e, false, false)
      end

      socket.on_close do |_|
        reject!(socket, nil)
      end
    rescue e : Exception
      handle_exception(socket, e)
    end

    def send_transaction(transaction : Transaction, from : Chord::NodeContext? = nil)
      content = {transaction: transaction, from: from || @chord.context}

      _nodes = @chord.find_nodes

      unless @is_private
        if !from.nil? && from[:is_private]
          content = {transaction: transaction, from: @chord.context}
        end

        _nodes[:private_nodes].each do |private_node|
          next if !from.nil? && from[:is_private] && private_node[:context][:id] == from[:id]
          send(private_node[:socket], M_TYPE_NODE_BROADCAST_TRANSACTION, content)
        rescue e : Exception
          handle_exception(private_node[:socket], e)
        end

        if successor = _nodes[:successor]
          begin
            send(successor[:socket], M_TYPE_NODE_BROADCAST_TRANSACTION, content)
          rescue e : Exception
            handle_exception(successor[:socket], e)
          end
        end
      else
        if from.nil? || from[:is_private]
          if successor = _nodes[:successor]
            begin
              send(successor[:socket], M_TYPE_NODE_BROADCAST_TRANSACTION, content)
            rescue e : Exception
              handle_exception(successor[:socket], e)
            end
          end
        end
      end      
    end

    def broadcast_transaction(transaction : Transaction, from : Chord::NodeContext? = nil)
      info "new transaction coming: #{transaction.id}"

      @blockchain.add_transaction(transaction)

      send_transaction(transaction, from)
    end

    def send_block(block : Block, from : Chord::NodeContext? = nil)
      content = {block: block, from: from || @chord.context}

      _nodes = @chord.find_nodes

      unless @is_private
        if !from.nil? && from[:is_private]
          content = {
            block: block,
            from:  @chord.context,
          }
        end

        _nodes[:private_nodes].each do |private_node|
          next if !from.nil? && from[:is_private] && private_node[:context][:id] == from[:id]
          send(private_node[:socket], M_TYPE_NODE_BROADCAST_BLOCK, content)
        rescue e : Exception
          handle_exception(private_node[:socket], e)
        end

        if successor = _nodes[:successor]
          begin
            send(successor[:socket], M_TYPE_NODE_BROADCAST_BLOCK, content)
          rescue e : Exception
            handle_exception(successor[:socket], e)
          end
        end
      else
        if from.nil? || from[:is_private]
          if successor = _nodes[:successor]
            begin
              send(successor[:socket], M_TYPE_NODE_BROADCAST_BLOCK, content)
            rescue e : Exception
              handle_exception(successor[:socket], e)
            end
          end
        end
      end
    end

    def broadcast_block(socket : HTTP::WebSocket, block : Block, from : Chord::NodeContext? = nil)
      if @blockchain.latest_index + 1 == block.index
        begin
          info "new block coming: #{light_cyan(@blockchain.chain.size)}"

          @blockchain.push_block?(block)
        rescue e : Exception
          warning "coming block has been rejected for the reason: #{e.message}"
        ensure
          send_block(block, from)
        end
      elsif @blockchain.latest_index == block.index
        warning "blockchain conflicted at #{block.index}"
        warning "ignore the block. (#{light_cyan(@blockchain.chain.size)})"

        # todo
        # @last_conflicted = block.index

        send_block(block, from)
      elsif @blockchain.latest_index + 1 < block.index
        warning "require new chain: #{@blockchain.latest_block.index} for #{block.index}"

        sync_chain(socket)

        send_block(block, from)
      else
        warning "received old block, will be ignored"

        send_block(block, from)

        if predecessor = @chord.find_predecessor?
          begin
            send(
              predecessor[:socket],
              M_TYPE_NODE_ASK_REQUEST_CHAIN,
              {
                latest_index: @blockchain.latest_block.index,
              }
            )
          rescue e : Exception
            handle_exception(predecessor[:socket], e)
          end
        end
      end
    end

    private def handle_exception(socket : HTTP::WebSocket, e : Exception, reject : Bool = true, show_backtrace : Bool = true)
      if error_message = e.message
        error error_message
      else
        error "unknown error"
      end

      reject!(socket, e) if reject

      error e.backtrace.not_nil!.join("\n") if show_backtrace
    end

    private def _broadcast_transaction(socket, _content)
      return unless @flag == FLAG_SETUP_DONE

      _m_content = M_CONTENT_NODE_BROADCAST_TRANSACTION.from_json(_content)

      transaction = _m_content.transaction
      from = _m_content.from

      broadcast_transaction(transaction, from)
    end

    private def _broadcast_block(socket, _content)
      return unless @flag == FLAG_SETUP_DONE

      _m_content = M_CONTENT_NODE_BROADCAST_BLOCK.from_json(_content)

      block = _m_content.block
      from = _m_content.from

      broadcast_block(socket, block, from)
    end

    private def _request_chain(socket, _content)
      _m_content = M_CONTENT_NODE_REQUEST_CHAIN.from_json(_content)

      latest_index = _m_content.latest_index

      info "requested new chain: #{latest_index}"

      send(socket, M_TYPE_NODE_RECEIVE_CHAIN, {chain: @blockchain.subchain(latest_index)})

      sync_chain(socket) if latest_index > @blockchain.latest_block.index
    rescue e : Exception
      handle_exception(socket, e)
    end

    private def _receive_chain(socket, _content)
      _m_content = M_CONTENT_NODE_RECEIVE_CHAIN.from_json(_content)

      chain = _m_content.chain

      if _chain = chain
        info "received chain's size: #{_chain.size}"
      else
        info "received empty chain."
      end

      current_latest_index = @blockchain.latest_index

      if @blockchain.replace_chain(chain)
        info "chain updated: #{light_green(current_latest_index)} -> #{light_green(@blockchain.latest_index)}"
        @miners_manager.broadcast_latest_block(@blockchain)
      end

      if @flag == FLAG_BLOCKCHAIN_SYNCING
        @flag = FLAG_SETUP_PRE_DONE
        proceed_setup
      end
    end

    private def _ask_request_chain(socket, _content)
      _m_content = M_CONTENT_NODE_ASK_REQUEST_CHAIN.from_json(_content)

      _latest_index = _m_content.latest_index

      debug "be asked to request new chain"
      debug "requested: #{_latest_index}, yours #{@blockchain.latest_block.index}"

      if _latest_index > @blockchain.latest_block.index
        sync_chain(socket)
      end
    end

    private def reject!(socket : HTTP::WebSocket, _e : Exception?)
      @chord.clean_connection(socket)
      @miners_manager.clean_connection(socket)

      if e = _e
        if error_message = e.message
          error error_message
        end
      end
    end

    private def handlers
      [
        peer_handler,
        route_handler,
      ]
    end

    def proceed_setup
      return if @flag == FLAG_SETUP_DONE

      case @flag
      when FLAG_NONE
        if @connect_host && @connect_port
          @flag = FLAG_CONNECTING_NODES

          unless @is_private
            @chord.join_to(@connect_host.not_nil!, @connect_port.not_nil!)
          else
            @chord.join_to_private(self, @connect_host.not_nil!, @connect_port.not_nil!)
          end
        else
          warning "no connecting node has been specified"
          warning "so this node is standalone from other network"

          @flag = FLAG_BLOCKCHAIN_LOADING

          proceed_setup
        end
      when FLAG_BLOCKCHAIN_LOADING
        @blockchain.setup(self)

        info "loaded blockchain's size: #{light_cyan(@blockchain.chain.size)}"

        if !@database
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

    include Logger
    include Router
    include Protocol
    include Common::Color
    include NodeComponents
  end
end
