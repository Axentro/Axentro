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

require "./node/*"

module ::Axentro::Core
  struct NodeConnection
    property host : String
    property port : Int32
    property ssl : Bool

    def initialize(@host, @port, @ssl); end

    def to_s
      "#{host}:#{port}"
    end
  end

  class Node < HandleSocket
    alias Network = NamedTuple(
      prefix: String,
      name: String,
    )

    property phase : SetupPhase

    getter blockchain : Blockchain
    getter network_type : String
    getter chord : Chord
    getter database : Database
    getter miners_manager : MinersManager

    @miners_manager : MinersManager
    @clients_manager : ClientsManager

    @rpc_controller : Controllers::RPCController
    @rest_controller : Controllers::RESTController
    @pubsub_controller : Controllers::PubsubController
    @wallet_info_controller : Controllers::WalletInfoController

    MAX_SYNC_RETRY = 20
    @sync_retry_count : Int32 = 2
    @sync_retry_list : Set(NodeConnection) = Set(NodeConnection).new

    # child node gets this from parent on setup
    @sync_blocks_target_index : Int64 = 0_i64
    @validation_hash : String = ""

    # ameba:disable Metrics/CyclomaticComplexity
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
      @wallet : Wallet?,
      @wallet_address : String,
      @database_path : String,
      @database : Database,
      @developer_fund : DeveloperFund?,
      @official_nodes : OfficialNodes?,
      @exit_on_unofficial : Bool,
      @security_level_percentage : Int64,
      @sync_chunk_size : Int32,
      @record_nonces : Bool,
      @max_miners : Int32,
      @max_private_nodes : Int32,
      @whitelist : Array(String),
      @whitelist_message : String,
      @metrics_whitelist : Array(String),
      @use_ssl : Bool = false
    )
      welcome

      @phase = SetupPhase::NONE

      @network_type = @is_testnet ? "testnet" : "mainnet"
      @blockchain = Blockchain.new(@network_type, @wallet, @wallet_address, @database_path, @database, @developer_fund, @official_nodes, @security_level_percentage, @sync_chunk_size, @record_nonces, @max_miners, is_standalone?)
      @chord = Chord.new(@database, @connect_host, @connect_port, @public_host, @public_port, @ssl, @network_type, @is_private, @use_ssl, @max_private_nodes, @wallet_address, @blockchain.official_node, @exit_on_unofficial, @whitelist, @whitelist_message)
      @miners_manager = MinersManager.new(@blockchain, @is_private)
      @clients_manager = ClientsManager.new(@blockchain)

      @limiter = RateLimiter(String).new
      @limiter.bucket(:incoming_nonces, 1_u32, 30.seconds)

      # Configure HTTP throttle
      Defense.store = Defense::MemoryStore.new
      Defense.throttle("throttle requests per second for creating transactions via API", limit: 500, period: 1) do |request|
        if @phase == SetupPhase::DONE
          if request.resource == "/api/v1/transaction" && request.method == "POST"
            "request"
          end
        end
      end

      Defense.throttle("throttle requests per second for general API", limit: 10, period: 1) do |request|
        if @phase == SetupPhase::DONE
          remote_connection = NetworkUtil.get_remote_connection(request)
          if request.resource.starts_with?("/api")
            remote_connection.ip
          end
        end
      end

      Defense.blocklist("ban noisy miners") do |request|
        if @phase == SetupPhase::DONE
          remote_connection = NetworkUtil.get_remote_connection(request)
          banned = MinersManager.ban_list(@miners_manager.get_mortalities)
          result = banned.includes?(remote_connection.ip)
          METRICS_MINERS_BANNED_GAUGE[kind: "banned"].set banned.size
          if result
            METRICS_MINERS_COUNTER[kind: "banned"].inc
          end
          result
        else
          false
        end
      end

      Defense.blocklist("block requests to metrics") do |request|
        remote_connection = NetworkUtil.get_remote_connection(request)
        if request.path.starts_with?("/metrics")
          !@metrics_whitelist.includes?(remote_connection.ip)
        else
          false
        end
      end

      info "max private nodes allowed to connect is #{light_green(@max_private_nodes)}"
      info "max miners allowed to connect is #{light_green(@max_miners)}"
      info "your log level is #{light_green(log_level_text)}"
      info "record nonces is set to #{light_green(@record_nonces)}"

      if @whitelist.size > 0
        info "whitelist enabled: #{@whitelist.inspect}"
        info "whitelist message: #{@whitelist_message}"
      end

      debug "is_private: #{light_green(@is_private)}"
      debug "public url: #{light_green(@public_host)}:#{light_green(@public_port)}" unless @is_private
      debug "connecting node is using ssl?: #{light_green(@use_ssl)}"
      debug "network type: #{light_green(@network_type)}"

      @rpc_controller = Controllers::RPCController.new(@blockchain)
      @rest_controller = Controllers::RESTController.new(@blockchain)
      @pubsub_controller = Controllers::PubsubController.new(@blockchain)
      @wallet_info_controller = Controllers::WalletInfoController.new(@blockchain)

      wallet_network = Wallet.address_network_type(@wallet_address)

      unless wallet_network[:name] == @network_type
        error "wallet type mismatch"
        error "node's   network: #{@network_type}"
        error "wallet's network: #{wallet_network[:name]}"
        exit -1
      end

      if chain_network = @blockchain.database.chain_network_kind
        if chain_network != (@network_type == "mainnet" ? MAINNET : TESTNET)
          error "The database is of network type: #{chain_network[:name]} but you tried to start it as network type: #{@network_type}"
          exit -1
        end
      end

      @chord.set_node(self)
      spawn proceed_setup
    end

    private def is_standalone?
      @connect_host.nil?
    end

    def i_am_a_fast_node?
      @blockchain.official_node.i_am_a_fastnode?(@wallet_address)
    end

    def fastnode_is_online?
      return true if ENV.has_key?("AX_SET_DIFFICULTY")
      @blockchain.official_node.a_fastnode_is_online?(@chord.official_nodes_list[:online].map(&.[:address]))
    end

    def get_wallet
      @wallet
    end

    def get_node_id
      @chord.context.id
    end

    def has_no_connections?
      chord.connected_nodes[:successor_list].empty?
    end

    def is_private_node?
      @is_private
    end

    def wallet_info_controller
      @wallet_info_controller
    end

    def run!
      info "Axentro node started on #{light_green(@bind_host)}:#{light_green(@bind_port)}"

      node = HTTP::Server.new(handlers)
      node.bind_tcp(@bind_host, @bind_port)
      node.listen
    end

    private def sync_chain_from_point(index : Int64, socket : HTTP::WebSocket? = nil)
      _sync_chain(index, socket)
    end

    private def sync_chain(socket : HTTP::WebSocket? = nil)
      start_slow = database.highest_index_of_kind(BlockKind::SLOW)
      _sync_chain(start_slow, socket)
    end

    # mostly on the child unless child chain is longer than parent then it happens on parent too
    private def _sync_chain(slow_start : Int64, socket : HTTP::WebSocket? = nil)
      info "start synching chain from slow index: #{slow_start}"

      s = if _socket = socket
            _socket
          elsif predecessor = @chord.find_predecessor?
            predecessor.socket
          elsif successor = @chord.find_successor?
            successor.socket
          end

      if _s = s
        info "requesting to stream slow blocks from index: #{slow_start}"
        send(s, M_TYPE_NODE_REQUEST_STREAM_SLOW_BLOCK, {start_slow: slow_start})
      else
        warning "successor not found. skip synching blockchain"

        if @phase == SetupPhase::BLOCKCHAIN_SYNCING
          @phase = SetupPhase::TRANSACTION_SYNCING
          proceed_setup
        end
      end
    end

    # def get_latest_slow_index : Int64
    #   @blockchain.has_no_blocks? ? 0_i64 : @blockchain.latest_slow_block.index
    # end

    # def get_latest_fast_index : Int64
    #   @blockchain.has_no_blocks? ? 0_i64 : (@blockchain.latest_fast_block || @blockchain.get_genesis_block).index
    # end

    private def sync_transactions(socket : HTTP::WebSocket? = nil)
      info "start synching transactions"

      s = if _socket = socket
            _socket
          elsif predecessor = @chord.find_predecessor?
            predecessor.socket
          elsif successor = @chord.find_successor?
            successor.socket
          end

      if _s = s
        transactions = @blockchain.pending_slow_transactions + @blockchain.pending_fast_transactions

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
      WebSocketHandler.new("/peer") { |socket, context|
        peer(socket, context)
      }
    end

    private def v1_api_documentation_handler : ApiDocumentationHandler
      ApiDocumentationHandler.new("/", "/index.html")
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def peer(socket : HTTP::WebSocket, context : HTTP::Server::Context? = nil)
      socket.on_binary do |message|
        transport = Transport.from_msgpack(message)
        message_type = transport.type
        message_content = transport.content

        case message_type
        when M_TYPE_MINER_HANDSHAKE
          METRICS_MINERS_COUNTER[kind: "attempted_join"].inc
          @miners_manager.handshake(socket, context, message_content)
        when M_TYPE_MINER_FOUND_NONCE
          if _context = context
            if miner = @miners_manager.find?(socket)
              if @limiter.rate_limited?(:incoming_nonces, miner.mid)
                METRICS_MINERS_COUNTER[kind: "rate_limit"].inc
                remaining_duration = @limiter.rate_limited?(:incoming_nonces, miner.mid)
                duration = remaining_duration.is_a?(Time::Span) ? remaining_duration.seconds : 0
                warning "rate limiting miner (#{miner.ip}:#{miner.port}) : #{light_green(miner.name)} (#{miner.mid}) retry in #{duration} seconds"
                @miners_manager.send_warning(socket, "nonce was rejected due to exceeded rate limit - retry in #{duration} seconds", duration)
                next
              end
            end
          end
          @miners_manager.found_nonce(socket, message_content)
        when M_TYPE_CLIENT_HANDSHAKE
          @clients_manager.handshake(socket, message_content)
        when M_TYPE_CLIENT_UPGRADE
          @clients_manager.upgrade(socket, message_content)
        when M_TYPE_CLIENT_CONTENT
          @clients_manager.receive_content(message_content)
        when M_TYPE_CHORD_JOIN
          @chord.join(self, socket, message_content, false)
        when M_TYPE_CHORD_RECONNECT
          @chord.join(self, socket, message_content, true)
        when M_TYPE_CHORD_JOIN_PRIVATE
          @chord.join_private(self, socket, message_content, false)
        when M_TYPE_CHORD_RECONNECT_PRIVATE
          @chord.join_private(self, socket, message_content, true)
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
        when M_TYPE_CHORD_BROADCAST_NODE_JOINED
          _broadcast_node_joined(socket, message_content)
        when M_TYPE_NODE_REQUEST_STREAM_SLOW_BLOCK
          _request_stream_slow_block(socket, message_content)
        when M_TYPE_NODE_RECEIVE_STREAM_SLOW_BLOCK
          _receive_stream_slow_block(socket, message_content)
        when M_TYPE_NODE_REQUEST_STREAM_FAST_BLOCK
          _request_stream_fast_block(socket, message_content)
        when M_TYPE_NODE_RECEIVE_STREAM_FAST_BLOCK
          _receive_stream_fast_block(socket, message_content)
        when M_TYPE_NODE_BROADCAST_TRANSACTION
          _broadcast_transaction(socket, message_content)
        when M_TYPE_NODE_BROADCAST_BLOCK
          _broadcast_block(socket, message_content)
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
      if (successor.context.id != @chord.context.id) && (from.nil? || from.is_private)
        send(successor.socket, message_type, content)
      end
    end

    # def broadcast_on_chord(message_type, content, from : Chord::NodeContext? = nil)
    #   _nodes = @chord.find_nodes
    #   _all_public_nodes = @chord.find_all_nodes[:public_nodes]

    #   if @is_private
    #     if successor = _nodes[:successor]
    #       prevent_self_connecting_case(message_type, content, from, successor)
    #     end
    #   else
    #     _nodes[:private_nodes].each do |private_node|
    #       next if !from.nil? && from[:is_private] && private_node[:context][:id] == from[:id]
    #       send(private_node[:socket], message_type, content)
    #     end

    #     if successor = _nodes[:successor]
    #       if successor[:context][:id] != content[:from][:id]
    #         warning "sending to successor: #{successor[:context][:port]}, #{message_type}"
    #         send(successor[:socket], message_type, content)
    #       end

    #       _all_public_nodes.reject{|n| n[:host] == successor[:context][:host] && n[:port] == successor[:context][:port]}.each do |n|
    #         info "sending to node: #{n[:host]}:#{n[:port]}"
    #         end
    #     end

    #   end
    # end

    def send_on_chord(message_type, content, from : Chord::NodeContext? = nil)
      _nodes = @chord.find_nodes

      if @is_private
        if successor = _nodes[:successor]
          prevent_self_connecting_case(message_type, content, from, successor)
        end
      else
        _nodes[:private_nodes].each do |private_node|
          next if !from.nil? && from.is_private && private_node.context.id == from.id
          send(private_node.socket, message_type, content)
        end

        if successor = _nodes[:successor]
          if successor.context.id != content[:from].id
            debug "sending to successor: #{message_type}"
            send(successor.socket, message_type, content)
          end
        end
      end
    end

    def send_transaction(transaction : Transaction, from : Chord::NodeContext? = nil)
      content = if from.nil? || (!from.nil? && from.is_private)
                  {transaction: transaction, from: @chord.context}
                else
                  {transaction: transaction, from: from}
                end

      send_on_chord(M_TYPE_NODE_BROADCAST_TRANSACTION, content, from)
    end

    def broadcast_transaction(transaction : Transaction, from : Chord::NodeContext? = nil)
      debug "new #{transaction.kind} transaction coming: #{transaction.short_id}"

      send_transaction(transaction, from)

      @blockchain.add_transaction(transaction)
    end

    # ----- chord finger table -----
    private def _broadcast_node_joined(socket, _content)
      _m_content = MContentChordBroadcastNodeJoined.from_json(_content)
      joined_nodes = _m_content.nodes
      from = _m_content.from

      send_nodes_joined(joined_nodes, from)
      @chord.add_to_finger_table(joined_nodes)
    end

    def send_nodes_joined(joined_nodes : Array(Chord::NodeContext), from : Chord::NodeContext? = nil)
      content = if from.nil? || (!from.nil? && from.is_private)
                  {nodes: joined_nodes, from: @chord.context}
                else
                  {nodes: joined_nodes, from: from}
                end

      send_on_chord(M_TYPE_CHORD_BROADCAST_NODE_JOINED, content, from)
    end

    # ----- blocks -----

    def send_block(block : Block, from : Chord::NodeContext? = nil)
      debug "entering send_block"
      content = if from.nil? || (!from.nil? && from.is_private)
                  {block: block, from: @chord.context}
                else
                  {block: block, from: from}
                end

      debug "before send_on_chord"
      send_on_chord(M_TYPE_NODE_BROADCAST_BLOCK, content, from)
      debug "after send_on_chord.. exiting send_block"
    end

    def send_client_content(content : String, from : Chord::NodeContext? = nil)
      _content = if from.nil? || (!from.nil? && from.is_private)
                   {content: content, from: @chord.context}
                 else
                   {content: content, from: from}
                 end

      send_on_chord(M_TYPE_NODE_SEND_CLIENT_CONTENT, _content, from)
    end

    def broadcast_block(socket : HTTP::WebSocket, block : Block, from : Chord::NodeContext? = nil)
      info "New #{block.kind} block coming from peer with index: #{block.index}"
      case BlockKind.parse(block.kind)
      when BlockKind::SLOW
        broadcast_slow_block(socket, block, from)
      when BlockKind::FAST
        broadcast_fast_block(socket, block, from)
      end
    end

    private def broadcast_slow_block(socket : HTTP::WebSocket, block : Block, from : Chord::NodeContext? = nil)
      # random_secs = Random.rand(30)
      # warning "++++++++++++ sleeping #{random_secs} seconds before sending to try to cause chaos....."
      # warning "++++++++++++ sleeping 2 minutes before sending to try to cause chaos....."
      # sleep(Time::Span.new(seconds: random_secs))
      # sleep(120)
      # warning "++++++++++++ finished sleeping"

      latest_block = database.get_highest_block_for_kind!(BlockKind::SLOW)
      has_block = database.get_block(block.index)
      slow_sync = SlowSync.new(block, @blockchain.mining_block, has_block, latest_block)
      state = slow_sync.process

      case state
      when SlowSyncState::CREATE
        execute_create(socket, block, latest_block, from)
      when SlowSyncState::REPLACE
        execute_replace(socket, block, latest_block, from)
      when SlowSyncState::REJECT_OLD
        execute_reject(socket, block, latest_block, RejectBlockReason::OLD, from)
      when SlowSyncState::REJECT_VERY_OLD
        execute_reject(socket, block, latest_block, RejectBlockReason::VERY_OLD, from)
      when SlowSyncState::SYNC
        execute_sync(socket, block, latest_block, from)
      else
        raise "Error - unknown SlowSyncState: #{state}"
      end
    rescue e : Exception
      error (e.message || "broadcast_slow_block unknown error: #{e.inspect}")
    ensure
      send_block(block, from)
    end

    private def sync_chain_on_error(conflicted_index : Int64, latest_local_index : Int64, count : Int32, socket : HTTP::WebSocket)
      index = database.lowest_slow_index_after_block(latest_local_index - count) || latest_local_index

      warning "sync_chain_on_error: attempting to re-sync from failed block #{conflicted_index} with index: #{index}"
      sync_chain_from_point(index, socket)
    end

    private def execute_create(socket : HTTP::WebSocket, block : Block, latest_block : Block, from : Chord::NodeContext?)
      info "received block: #{block.index} from peer that I don't have in my db"

      # random_secs = Random.rand(30)
      # warning "++++++++++++ sleeping #{random_secs} seconds before sending to try to cause chaos....."
      # sleep(Time::Span.new(seconds: random_secs))
      # warning "++++++++++++ finished sleeping"

      # we check the transactions that are incoming in valid_block here.
      if _block = @blockchain.valid_block?(block, false, true)
        info "received block: #{_block.index} was valid so storing in my db"
        debug "slow: finished sending new block on to peer"
        @miners_manager.forget_most_difficult
        debug "slow: about to create the new block locally"
        new_block(_block)

        info "#{magenta("NEW SLOW BLOCK broadcasted")}: #{light_green(_block.index)} at difficulty: #{light_cyan(_block.difficulty)}"
      end
    rescue e : Exception
      warning "received block: #{block.index} from peer that I don't have in my db was invalid"
      warning "error was: #{e.message || "unknown error"}"

      sync_chain_on_error(block.index, latest_block.index, 2, socket)
    end

    private def execute_replace(socket : HTTP::WebSocket, block : Block, latest_block : Block, from : Chord::NodeContext?)
      warning "slow: blockchain conflicted at incoming #{block.index} and local (#{light_cyan(latest_block.index)})"
      warning "slow: local timestamp: #{latest_block.timestamp}, arriving block timestamp: #{block.timestamp}"
      warning "slow: arriving block's timestamp indicates it was minted earlier than latest local block (or at the same time but has different hash)"

      # don't check transactions here as will fail since they already exist in the existing block
      # also don't check as lastest block here as we are doing a replace
      if _block = @blockchain.valid_block?(block, true, true)
        warning "arriving block #{_block.index} passes validity checks, making the arriving block our local latest"
        # replace here does check the transactions lower down
        @blockchain.replace_with_block_from_peer(_block)
        @miners_manager.forget_most_difficult
      end
    rescue e : Exception
      warning "arriving block #{block.index} failed validity check, we can't make it our local latest"
      warning "error was: #{e.message || "unknown error"}"

      sync_chain_on_error(block.index, latest_block.index, 2, socket)
    end

    private def execute_reject(socket : HTTP::WebSocket, block : Block, latest_block : Block, reason : RejectBlockReason, from : Chord::NodeContext?)
      case reason
      when RejectBlockReason::OLD
        warning "slow: blockchain conflicted at incoming #{block.index} and local (#{light_cyan(latest_block.index)})"
        warning "slow: local timestamp: #{latest_block.timestamp}, arriving block timestamp: #{block.timestamp}"
        warning "keeping our local block: #{latest_block.index} and ignoring the block: #{block.index} because local one was minted first or (at the same time but with identical hash)"
      when RejectBlockReason::VERY_OLD
        warning "ignore very old block: #{block.index} because local latest is: #{latest_block.index}"
      else
        warning "unknown rejection reason #{reason} - so ignoring it"
      end
    end

    private def execute_sync(socket : HTTP::WebSocket, block : Block, latest_block : Block, from : Chord::NodeContext?)
      warning "slow: require new chain after - local: #{latest_block.index} for incoming from peer: #{block.index}"
      sync_chain(socket)
    end

    def fast_block_was_signed_by_official_fast_node?(block : Block) : Bool
      debug "verifying fast block was signed by official fast node"
      hash_salt = block.hash
      signature = block.signature
      address = block.address
      public_key = block.public_key
      @blockchain.official_node.i_am_a_fastnode?(address) && KeyUtils.verify_signature(hash_salt, signature, public_key)
    end

    # There is only 1 fast node on the network in phase 1 - so use this simple logic until that changes
    private def broadcast_fast_block(socket : HTTP::WebSocket, block : Block, from : Chord::NodeContext? = nil)
      if fast_block_was_signed_by_official_fast_node?(block)
        if @blockchain.database.do_i_have_block(block.index)
          if i_am_a_fast_node?
            warning "not sending on incoming fast block: #{block.index} because I am the fast node and I already have the block"
          else
            info "sending on incoming fast block: #{block.index} (I already have it and am not the fast node)"
            send_block(block, from)
          end
        else
          info "receiving new incoming fast block: #{block.index} - I don't already have it"
          if _block = @blockchain.valid_block?(block)
            debug "fast: about to create the new block locally"
            new_block(_block)
            send_block(block, from)
            info "#{magenta("NEW FAST BLOCK broadcasted")}: #{light_green(_block.index)}"
          else
            warning "the incoming new fast block: #{block.index} was invalid so discarding it"
          end
        end
      else
        warning "fast block arriving from peer was not signed by a valid fast node - ignoring this block"
      end
    rescue e : Exception
      error e.message || "no message content for exception"
    end

    def new_block(block : Block)
      @blockchain.push_slow_block(block)

      @pubsub_controller.broadcast_latest_block
      @wallet_info_controller.update_wallet_information(block.transactions)
    end

    def clean_connection(socket)
      @chord.clean_connection(socket)
      @miners_manager.clean_connection(socket)
      @clients_manager.clean_connection(socket)
    end

    def miners
      @miners_manager.miners
    end

    def miners_manager
      @miners_manager
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

    # on parent
    private def _request_stream_slow_block(socket, _content)
      _m_content = MContentNodeRequestStreamSlowBlock.from_json(_content)
      start_slow = _m_content.start_slow
      info "requested stream slow chain from slow index: #{start_slow}"

      target_slow = database.highest_index_of_kind(BlockKind::SLOW)
      stream_size = 0
      database.stream_blocks_from(start_slow, BlockKind::SLOW) do |block, total_size|
        stream_size = total_size
        send(socket, M_TYPE_NODE_RECEIVE_STREAM_SLOW_BLOCK, {block: block, start_slow: start_slow, target_slow: target_slow, total_size: total_size})
      end
      info "finished streaming #{stream_size} slow blocks to peer"

      if start_slow > target_slow
        send(socket, M_TYPE_NODE_REQUEST_STREAM_SLOW_BLOCK, {start_slow: target_slow})
      end
    end

    # on child
    private def _receive_stream_slow_block(socket, _content)
      _m_content = MContentNodeReceiveStreamSlowBlock.from_json(_content)
      target_slow = _m_content.target_slow
      block = Block.from_json(_m_content.block.to_json)

      progress("slow block ##{block.index} was received", block.index, target_slow)
      database.inplace_block(block)

      if block.index == target_slow
        start_fast = database.highest_index_of_kind(BlockKind::FAST)
        send(socket, M_TYPE_NODE_REQUEST_STREAM_FAST_BLOCK, {start_fast: start_fast})
      end

      @sync_retry_count = 2
    rescue
      warning "error receiving slow block stream"

      if @sync_retry_count <= MAX_SYNC_RETRY
        next_connection = retry_sync
        warning "retry sync from node: #{next_connection.host}:#{next_connection.port}"

        node_socket = HTTP::WebSocket.new(next_connection.host, "/peer?node", next_connection.port, next_connection.ssl)

        peer(node_socket)

        spawn do
          node_socket.run
        rescue e : Exception
          handle_exception(node_socket, e)
        end

        target_slow = database.highest_index_of_kind(BlockKind::SLOW)
        sync_chain_on_error(target_slow, target_slow, @sync_retry_count, node_socket)
      end
    end

    # on parent
    private def _request_stream_fast_block(socket, _content)
      _m_content = MContentNodeRequestStreamFastBlock.from_json(_content)
      start_fast = _m_content.start_fast
      info "requested stream fast chain from fast index: #{start_fast}"

      target_fast = database.highest_index_of_kind(BlockKind::FAST)
      if target_fast == 0_i64
        # if no fast blocks just send the genesis block (the child will ignore it but continue setup)
        _block = database.get_block(0_i64)
        send(socket, M_TYPE_NODE_RECEIVE_STREAM_FAST_BLOCK, {block: _block, start_fast: start_fast, target_fast: target_fast, total_size: 0})
      else
        database.stream_blocks_from(start_fast, BlockKind::FAST) do |block, total_size|
          send(socket, M_TYPE_NODE_RECEIVE_STREAM_FAST_BLOCK, {block: block, start_fast: start_fast, target_fast: target_fast, total_size: total_size})
        end
      end

      if start_fast > target_fast
        send(socket, M_TYPE_NODE_REQUEST_STREAM_FAST_BLOCK, {start_fast: target_fast})
      end
    end

    # on child
    private def _receive_stream_fast_block(socket, _content)
      _m_content = MContentNodeReceiveStreamFastBlock.from_json(_content)
      start_fast = _m_content.start_fast
      target_fast = _m_content.target_fast
      block = Block.from_json(_m_content.block.to_json)

      progress("fast block ##{block.index} was received", block.index, target_fast)
      if block.index > start_fast
        database.inplace_block(block)
      end

      if block.index == target_fast
        info "finished writing to db for completed sync and starting db validation"

        result = database.validate_local_db_blocks

        if result.success
          @sync_retry_count = 2
          info "all blocks successfully validated at block: #{result.index}"
          if @phase == SetupPhase::BLOCKCHAIN_SYNCING
            @phase = SetupPhase::TRANSACTION_SYNCING
            proceed_setup
          end
        else
          # retry sync
          warning "failed to validated blocks at block: #{result.index} - starting sync retry"
          if @sync_retry_count <= MAX_SYNC_RETRY
            next_connection = retry_sync
            warning "retry sync from node: #{next_connection}"

            node_socket = HTTP::WebSocket.new(next_connection.host, "/peer?node", next_connection.port, next_connection.ssl)

            peer(node_socket)

            spawn do
              node_socket.run
            rescue e : Exception
              handle_exception(node_socket, e)
            end

            sync_chain_on_error(result.index, database.highest_index_of_kind(BlockKind::SLOW), @sync_retry_count, node_socket)
          end
        end
      end
    end

    private def retry_sync
      node_connections = @chord.find_all_nodes[:public_nodes].map { |nc| NodeConnection.new(nc.host, nc.port, nc.ssl) }
      next_connections = node_connections.reject { |nc| @sync_retry_list.map(&.to_s).includes?(nc.to_s) }

      if next_connections.size == 1
        @sync_retry_list.clear
        @sync_retry_count += 2
      end

      next_connection = next_connections.first
      @sync_retry_list << next_connection
      next_connection
    end

    private def _request_transactions(socket, _content)
      MContentNodeRequestTransactions.from_json(_content)

      info "requested transactions"

      transactions = @blockchain.pending_slow_transactions + @blockchain.pending_fast_transactions

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

      @blockchain.replace_slow_transactions(transactions.select(&.is_slow_transaction?))
      @blockchain.replace_fast_transactions(transactions.select(&.is_fast_transaction?))

      if @phase == SetupPhase::TRANSACTION_SYNCING
        @phase = SetupPhase::PRE_DONE
        proceed_setup
      end
    end

    private def handlers
      metrics_handler = Crometheus.default_registry.get_handler
      Crometheus.default_registry.path = "/metrics"
      [
        Defense::Handler.new,
        peer_handler,
        @rpc_controller.get_handler,
        @rest_controller.get_handler,
        @pubsub_controller.get_handler,
        @wallet_info_controller.get_handler,
        Crometheus::Middleware::HttpCollector.new,
        metrics_handler,
        HTTP::StaticFileHandler.new("api/v1/dist", true, false),
        v1_api_documentation_handler,
      ]
    end

    private def phase_connecting_nodes
      @phase = SetupPhase::CONNECTING_NODES

      if @is_private
        debug "doing join to private"
        @chord.join_to_private(self, @connect_host.not_nil!, @connect_port.not_nil!)
      else
        debug "doing join to public"
        @chord.join_to(self, @connect_host.not_nil!, @connect_port.not_nil!)
      end
    end

    def setup_connectivity
      if @connect_host && @connect_port
        phase_connecting_nodes
      else
        warning "no connecting node has been specified"
        warning "so this node is standalone from other network"
        @phase = SetupPhase::PRE_DONE
        proceed_setup
      end
    end

    def load_blockchain_from_database
      @blockchain.setup(self)

      if database.total_blocks == 0
        info "There were no blocks in the database"
        @phase = SetupPhase::CONNECTING_NODES
        proceed_setup
      else
        info "loaded blockchain's total size: #{light_cyan(database.total_blocks)}"
        info "highest slow block index: #{light_cyan(database.highest_index_of_kind(BlockKind::SLOW))}"
        info "highest fast block index: #{light_cyan(database.highest_index_of_kind(BlockKind::FAST))}"

        if !@database
          warning "no database has been specified"
        end

        unless @developer_fund.nil?
          info "Developer fund has been invoked based on this configuration: #{@developer_fund.not_nil!.get_path}"
        end
        @phase = SetupPhase::CONNECTING_NODES
        proceed_setup
      end
    end

    def proceed_setup
      return if @phase == SetupPhase::DONE

      case @phase
      when SetupPhase::NONE
        @phase = SetupPhase::BLOCKCHAIN_VALIDATING
        proceed_setup
      when SetupPhase::BLOCKCHAIN_VALIDATING
        load_blockchain_from_database
      when SetupPhase::CONNECTING_NODES
        setup_connectivity
      when SetupPhase::BLOCKCHAIN_SYNCING
        sync_chain
      when SetupPhase::TRANSACTION_SYNCING
        sync_transactions
      when SetupPhase::PRE_DONE
        info "successfully setup the node"

        # if not private then start fast txn loop
        if !@is_private
          spawn @blockchain.process_fast_transactions
        end

        @phase = SetupPhase::DONE
      end
    end

    def send_content_to_client(from_address : String, to : String, message : String, from = nil) : Bool
      @clients_manager.send_content(from_address, to, message, from)
    end

    include Protocol
    include Common::Color
    include NodeComponents
    include Metrics
  end
end
