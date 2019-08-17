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
  class Node < HandleSocket
    alias Network = NamedTuple(
      prefix: String,
      name: String,
    )

    property phase : SetupPhase

    getter blockchain : Blockchain
    getter network_type : String
    getter chord : Chord

    @miners_manager : MinersManager
    @clients_manager : ClientsManager

    @rpc_controller : Controllers::RPCController
    @rest_controller : Controllers::RESTController
    @pubsub_controller : Controllers::PubsubController

    @conflicted_index : Int64? = nil

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
      @developer_fund : DeveloperFund?,
      @use_ssl : Bool = false
    )
      welcome

      @blockchain = Blockchain.new(@wallet, @database, @developer_fund)
      @network_type = @is_testnet ? "testnet" : "mainnet"
      @chord = Chord.new(@public_host, @public_port, @ssl, @network_type, @is_private, @use_ssl)
      @miners_manager = MinersManager.new(@blockchain)
      @clients_manager = ClientsManager.new(@blockchain)

      @phase = SetupPhase::NONE

      info "your log level is #{light_green(log_level_text)}"

      debug "is_private: #{light_green(@is_private)}"
      debug "public url: #{light_green(@public_host)}:#{light_green(@public_port)}" unless @is_private
      debug "connecting node is using ssl?: #{light_green(@use_ssl)}"
      debug "network type: #{light_green(@network_type)}"

      @rpc_controller = Controllers::RPCController.new(@blockchain)
      @rest_controller = Controllers::RESTController.new(@blockchain)
      @pubsub_controller = Controllers::PubsubController.new(@blockchain)

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
      info "start running Sushi's node on #{light_green(@bind_host)}:#{light_green(@bind_port)}"

      node = HTTP::Server.new(handlers)
      node.bind_tcp(@bind_host, @bind_port)
      node.listen
    end

    private def sync_chain(socket : HTTP::WebSocket? = nil)
      info "start synching blockchain"

      s = if _socket = socket
            _socket
          elsif predecessor = @chord.find_predecessor?
            predecessor[:socket]
          elsif successor = @chord.find_successor?
            successor[:socket]
          end

      if _s = s
        debug "asking to sync chain at index #{@conflicted_index.nil? ? @blockchain.latest_index : @conflicted_index.not_nil!}"
        send(
          _s,
          M_TYPE_NODE_REQUEST_CHAIN,
          {
            latest_index: @conflicted_index.nil? ? @blockchain.latest_index : @conflicted_index.not_nil!,
          }
        )
      else
        warning "successor not found. skip synching blockchain"

        if @phase == SetupPhase::BLOCKCHAIN_SYNCING
          @phase = SetupPhase::TRANSACTION_SYNCING
          proceed_setup
        end
      end
    end

    private def sync_transactions(socket : HTTP::WebSocket? = nil)
      info "start synching transactions"

      s = if _socket = socket
            _socket
          elsif predecessor = @chord.find_predecessor?
            predecessor[:socket]
          elsif successor = @chord.find_successor?
            successor[:socket]
          end

      if _s = s
        # TODO Fixme
        transactions = @blockchain.pending_slow_transactions

        send(
          _s,
          M_TYPE_NODE_REQUEST_TRANSACTIONS,
          {
            transactions: transactions,
          }
        )
      else
        warning "successor not found. skip synching transactions"

        if @phase == SetupPhase::TRANSACTION_SYNCING
          @phase = SetupPhase::PRE_DONE
          proceed_setup
        end
      end
    end

    private def peer_handler : WebSocketHandler
      WebSocketHandler.new("/peer") { |socket, _| peer(socket) }
    end

    private def v1_api_documentation_handler : ApiDocumentationHandler
      ApiDocumentationHandler.new("/", "api/v1/dist/index.html")
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def peer(socket : HTTP::WebSocket)
      socket.on_message do |message|
        message_json = JSON.parse(message)
        message_type = message_json["type"].as_i
        message_content = message_json["content"].as_s

        case message_type
        when M_TYPE_MINER_HANDSHAKE
          @miners_manager.handshake(socket, message_content)
        when M_TYPE_MINER_FOUND_NONCE
          @miners_manager.found_nonce(socket, message_content)
        when M_TYPE_CLIENT_HANDSHAKE
          @clients_manager.handshake(socket, message_content)
        when M_TYPE_CLIENT_UPGRADE
          @clients_manager.upgrade(socket, message_content)
        when M_TYPE_CLIENT_CONTENT
          @clients_manager.receive_content(message_content)
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
        when M_TYPE_NODE_REQUEST_TRANSACTIONS
          _request_transactions(socket, message_content)
        when M_TYPE_NODE_RECEIVE_TRANSACTIONS
          _receive_transactions(socket, message_content)
        when M_TYPE_NODE_SEND_CLIENT_CONTENT
          _receive_client_content(socket, message_content)
        end
      rescue e : Exception
        handle_exception(socket, e)
      end

      socket.on_close do |_|
        clean_connection(socket)
      end
    rescue e : Exception
      handle_exception(socket, e)
    end

    private def prevent_self_connecting_case(message_type, content, from, successor)
      if (successor[:context][:id] != @chord.context[:id]) && (from.nil? || from[:is_private])
        send(successor[:socket], message_type, content)
      end
    end

    def send_on_chord(message_type, content, from : Chord::NodeContext? = nil)
      _nodes = @chord.find_nodes

      if @is_private
        if successor = _nodes[:successor]
          prevent_self_connecting_case(message_type, content, from, successor)
        end
      else
        _nodes[:private_nodes].each do |private_node|
          next if !from.nil? && from[:is_private] && private_node[:context][:id] == from[:id]
          send(private_node[:socket], message_type, content)
        end

        if successor = _nodes[:successor]
          if successor[:context][:id] != content[:from][:id]
            send(successor[:socket], message_type, content)
          end
        end
      end
    end

    def send_transaction(transaction : Transaction, from : Chord::NodeContext? = nil)
      content = if from.nil? || (!from.nil? && from[:is_private])
                  {transaction: transaction, from: @chord.context}
                else
                  {transaction: transaction, from: from}
                end

      send_on_chord(M_TYPE_NODE_BROADCAST_TRANSACTION, content, from)
    end

    def broadcast_transaction(transaction : Transaction, from : Chord::NodeContext? = nil)
      info "new #{transaction.kind} transaction coming: #{transaction.short_id}"

      send_transaction(transaction, from)

      @blockchain.add_transaction(transaction)
    end

    def send_block(block : SlowBlock | FastBlock, from : Chord::NodeContext? = nil)
      debug "entering send_block"
      content = if from.nil? || (!from.nil? && from[:is_private])
                  {block: block, from: @chord.context}
                else
                  {block: block, from: from}
                end

      debug "before send_on_chord"
      send_on_chord(M_TYPE_NODE_BROADCAST_BLOCK, content, from)
      debug "after send_on_chord.. exiting send_block"
    end

    def send_client_content(content : String, from : Chord::NodeContext? = nil)
      _content = if from.nil? || (!from.nil? && from[:is_private])
                   {content: content, from: @chord.context}
                 else
                   {content: content, from: from}
                 end

      send_on_chord(M_TYPE_NODE_SEND_CLIENT_CONTENT, _content, from)
    end

    def broadcast_block(socket : HTTP::WebSocket, block : SlowBlock | FastBlock, from : Chord::NodeContext? = nil)
      debug "new block coming: #{light_cyan(@blockchain.chain.size)}"
      debug "block index from peer: #{block.index}"
      if @blockchain.latest_index + 1 == block.index
        debug "sending new block on to peer"
        send_block(block, from)
        debug "finished sending new block on to peer"
        if _block = @blockchain.valid_block?(block)
          @miners_manager.forget_most_difficult
          debug "about to create the new block locally"
          new_block(_block)
        end
      elsif @blockchain.latest_index == block.index
        warning "blockchain conflicted at #{block.index} (#{light_cyan(@blockchain.chain.size)})"

        @conflicted_index ||= block.index

        send_block(block, from)
      elsif @blockchain.latest_index + 1 < block.index
        warning "require new chain: #{@blockchain.latest_block.index} for #{block.index}"

        sync_chain(socket)

        send_block(block, from)
      else
        warning "received old block, will be ignored"

        send_block(block, from)

        if predecessor = @chord.find_predecessor?
          send(
            predecessor[:socket],
            M_TYPE_NODE_ASK_REQUEST_CHAIN,
            {
              latest_index: @blockchain.latest_block.index,
            }
          )
        end
      end
    end

    def new_block(block : SlowBlock | FastBlock)
      @blockchain.push_block(block)
      @pubsub_controller.broadcast_latest_block
    end

    def clean_connection(socket : HTTP::WebSocket)
      @chord.clean_connection(socket)
      @miners_manager.clean_connection(socket)
      @clients_manager.clean_connection(socket)
    end

    def miners
      @miners_manager.miners
    end

    def miners_broadcast
      @miners_manager.broadcast
    end

    private def _broadcast_transaction(socket, _content)
      return unless @phase == SetupPhase::DONE

      _m_content = MContentNodeBroadcastTransaction.from_json(_content)

      transaction = _m_content.transaction
      from = _m_content.from

      broadcast_transaction(transaction, from)
    end

    private def _broadcast_block(socket, _content)
      return unless @phase == SetupPhase::DONE

      _m_content = MContentNodeBroadcastBlock.from_json(_content)

      block = _m_content.block
      from = _m_content.from

      broadcast_block(socket, block, from)
    end

    private def _receive_client_content(socket, _content)
      return unless @phase == SetupPhase::DONE

      _m_content = MContentNodeSendClientContent.from_json(_content)

      content = _m_content.content
      from = _m_content.from

      @clients_manager.receive_content(content, from)
    end

    private def _request_chain(socket, _content)
      _m_content = MContentNodeRequestChain.from_json(_content)

      latest_index = _m_content.latest_index

      info "requested new chain: #{latest_index}"

      send(socket, M_TYPE_NODE_RECEIVE_CHAIN, {chain: @blockchain.subchain(latest_index)})
      debug "chain sent to peer for sync"

      sync_chain(socket) if latest_index > @blockchain.latest_block.index
    end

    private def _receive_chain(socket, _content)
      _m_content = MContentNodeReceiveChain.from_json(_content)

      chain = _m_content.chain

      if _chain = chain
        info "received #{_chain.size} blocks"
      else
        info "received empty chain"
      end

      current_latest_index = @blockchain.latest_index

      if @blockchain.replace_chain(chain)
        info "chain updated: #{light_green(current_latest_index)} -> #{light_green(@blockchain.latest_index)}"
        @miners_manager.broadcast

        @conflicted_index = nil
      end

      if @phase == SetupPhase::BLOCKCHAIN_SYNCING
        @phase = SetupPhase::TRANSACTION_SYNCING
        proceed_setup
      end
    end

    private def _ask_request_chain(socket, _content)
      _m_content = MContentNodeAskRequestChain.from_json(_content)

      _latest_index = _m_content.latest_index

      verbose "be asked to request new chain"
      verbose "requested: #{_latest_index}, yours #{@blockchain.latest_block.index}"

      if _latest_index > @blockchain.latest_block.index
        sync_chain(socket)
      end
    end

    private def _request_transactions(socket, _content)
      MContentNodeRequestTransactions.from_json(_content)

      info "requested transactions"

      # TODO Fixme
      transactions = @blockchain.pending_slow_transactions

      send(
        socket,
        M_TYPE_NODE_RECEIVE_TRANSACTIONS,
        {
          transactions: transactions,
        }
      )
    end

    private def _receive_transactions(socket, _content)
      _m_content = MContentNodeReceiveTransactions.from_json(_content)

      transactions = _m_content.transactions

      info "received #{transactions.size} transactions"

      # TODO Fixme
      @blockchain.replace_slow_transactions(transactions)

      if @phase == SetupPhase::TRANSACTION_SYNCING
        @phase = SetupPhase::PRE_DONE
        proceed_setup
      end
    end

    private def handlers
      [
        peer_handler,
        @rpc_controller.get_handler,
        @rest_controller.get_handler,
        @pubsub_controller.get_handler,
        HTTP::StaticFileHandler.new("api/v1/dist", true, false),
        v1_api_documentation_handler,
      ]
    end

    private def phase_connecting_nodes
      @phase = SetupPhase::CONNECTING_NODES

      if @is_private
        @chord.join_to_private(self, @connect_host.not_nil!, @connect_port.not_nil!)
      else
        @chord.join_to(self, @connect_host.not_nil!, @connect_port.not_nil!)
      end
    end

    def proceed_setup
      return if @phase == SetupPhase::DONE

      case @phase
      when SetupPhase::NONE
        if @connect_host && @connect_port
          phase_connecting_nodes
        else
          warning "no connecting node has been specified"
          warning "so this node is standalone from other network"

          @phase = SetupPhase::BLOCKCHAIN_LOADING

          proceed_setup
        end
        unless @developer_fund.nil?
          info "Developer fund has been invoked based on this configuration: #{@developer_fund.not_nil!.get_path}"
        end
      when SetupPhase::BLOCKCHAIN_LOADING
        @blockchain.setup(self)

        info "loaded blockchain's size: #{light_cyan(@blockchain.chain.size)}"

        if @database
          @conflicted_index = nil
        else
          warning "no database has been specified"
        end

        @phase = SetupPhase::BLOCKCHAIN_SYNCING

        proceed_setup
      when SetupPhase::BLOCKCHAIN_SYNCING
        sync_chain
      when SetupPhase::TRANSACTION_SYNCING
        sync_transactions
      when SetupPhase::PRE_DONE
        info "successfully setup the node"

        @phase = SetupPhase::DONE
      end
    end

    def send_content_to_client(from_address : String, to : String, message : String, from = nil) : Bool
      @clients_manager.send_content(from_address, to, message, from)
    end

    include Protocol
    include Common::Color
    include NodeComponents
  end
end
