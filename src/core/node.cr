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

    @miners_manager : MinersManager
    @clients_manager : ClientsManager

    @rpc_controller : Controllers::RPCController
    @rest_controller : Controllers::RESTController
    @pubsub_controller : Controllers::PubsubController
    @wallet_info_controller : Controllers::WalletInfoController

    MAX_SYNC_RETRY = 20
    @sync_retry_1_count : Int32 = 0
    @sync_retry_2_count : Int32 = 0
    @sync_giving_up : Bool = false

    # child node gets this from parent on setup
    @sync_slow_blocks_target_index : Int64 = 0_i64
    @sync_fast_blocks_target_index : Int64 = 0_i64
    @validation_hash : String = ""

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
      @use_ssl : Bool = false
    )
      welcome

      # Configure HTTP throttle
      Defense.store = Defense::MemoryStore.new
      Defense.throttle("throttle requests per second for creating transactions via API", limit: 500, period: 1) do |request|
        if request.resource == "/api/v1/transaction" && request.method == "POST"
          "request"
        end
      end

      @network_type = @is_testnet ? "testnet" : "mainnet"
      @blockchain = Blockchain.new(@network_type, @wallet, @database_path, @database, @developer_fund, @official_nodes, @security_level_percentage, @sync_chunk_size, @record_nonces, @max_miners, is_standalone?)
      @chord = Chord.new(@public_host, @public_port, @ssl, @network_type, @is_private, @use_ssl, @max_private_nodes, @wallet.address, @blockchain.official_node, @exit_on_unofficial)
      @miners_manager = MinersManager.new(@blockchain)
      @clients_manager = ClientsManager.new(@blockchain)

      @phase = SetupPhase::NONE

      info "max private nodes allowed to connect is #{light_green(@max_private_nodes)}"
      info "max miners allowed to connect is #{light_green(@max_miners)}"
      info "your log level is #{light_green(log_level_text)}"
      info "record nonces is set to #{light_green(@record_nonces)}"

      debug "is_private: #{light_green(@is_private)}"
      debug "public url: #{light_green(@public_host)}:#{light_green(@public_port)}" unless @is_private
      debug "connecting node is using ssl?: #{light_green(@use_ssl)}"
      debug "network type: #{light_green(@network_type)}"

      @rpc_controller = Controllers::RPCController.new(@blockchain)
      @rest_controller = Controllers::RESTController.new(@blockchain)
      @pubsub_controller = Controllers::PubsubController.new(@blockchain)
      @wallet_info_controller = Controllers::WalletInfoController.new(@blockchain)

      wallet_network = Wallet.address_network_type(@wallet.address)

      unless wallet_network[:name] == @network_type
        error "wallet type mismatch"
        error "node's   network: #{@network_type}"
        error "wallet's network: #{wallet_network[:name]}"
        exit -1
      end

      spawn proceed_setup
    end

    private def is_standalone?
      @connect_host.nil?
    end

    def i_am_a_fast_node?
      @blockchain.official_node.i_am_a_fastnode?(@wallet.address)
    end

    def fastnode_is_online?
      return true if ENV.has_key?("AX_SET_DIFFICULTY")
      @blockchain.official_node.a_fastnode_is_online?(@chord.official_nodes_list[:online].map(&.[:address]))
    end

    def get_wallet
      @wallet
    end

    def get_node_id
      @chord.context[:id]
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

    private def sync_chain_from_point(slow_index : Int64, fast_index : Int64, socket : HTTP::WebSocket? = nil)
      _sync_chain(slow_index, fast_index, socket, false)
    end

    private def sync_chain(socket : HTTP::WebSocket? = nil, do_validate : Bool = true)
      slow_index = get_latest_slow_index
      fast_index = get_latest_fast_index
      _sync_chain(slow_index, fast_index, socket, do_validate)
    end

    # mostly on the child unless child chain is longer than parent then it happens on parent too
    private def _sync_chain(slow_index : Int64, fast_index : Int64, socket : HTTP::WebSocket? = nil, do_validate : Bool = true)
      info "start synching chain"

      s = if _socket = socket
            _socket
          elsif predecessor = @chord.find_predecessor?
            predecessor[:socket]
          elsif successor = @chord.find_successor?
            successor[:socket]
          end

      if _s = s
        slow_sync_index = slow_index
        fast_sync_index = fast_index
        info "asking to sync chain at indices slow: #{slow_sync_index}, fast: #{fast_sync_index}"

        if do_validate
          send(_s, M_TYPE_NODE_REQUEST_VALIDATION_CHALLENGE, {latest_slow_index: slow_sync_index, latest_fast_index: fast_sync_index})
        else
          send(_s, M_TYPE_NODE_REQUEST_CHAIN_SIZE, {chunk_size: @sync_chunk_size, latest_slow_index: slow_sync_index, latest_fast_index: fast_sync_index})
        end
      else
        warning "successor not found. skip synching blockchain"

        if @phase == SetupPhase::BLOCKCHAIN_SYNCING
          @phase = SetupPhase::TRANSACTION_SYNCING
          proceed_setup
        end
      end
    end

    def get_latest_slow_index : Int64
      @blockchain.has_no_blocks? ? 0_i64 : @blockchain.latest_slow_block.index
    end

    def get_latest_fast_index : Int64
      @blockchain.has_no_blocks? ? 0_i64 : (@blockchain.latest_fast_block || @blockchain.get_genesis_block).index
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
          @phase = SetupPhase::MINER_NONCE_SYNCING
          proceed_setup
        end
      end
    end

    private def sync_miner_nonces(socket : HTTP::WebSocket? = nil)
      info "start syncing miner nonces"

      s = if _socket = socket
            _socket
          elsif predecessor = @chord.find_predecessor?
            predecessor[:socket]
          elsif successor = @chord.find_successor?
            successor[:socket]
          end

      if _s = s
        miner_nonces = @blockchain.pending_miner_nonces
        send(
          _s,
          M_TYPE_NODE_REQUEST_MINER_NONCES,
          {
            nonces: miner_nonces,
          }
        )
      else
        warning "successor not found. skip syncing miner nonces"

        if @phase == SetupPhase::MINER_NONCE_SYNCING
          @phase = SetupPhase::PRE_DONE
          proceed_setup
        end
      end
    end

    private def peer_handler : WebSocketHandler
      WebSocketHandler.new("/peer") { |socket, _| peer(socket) }
    end

    private def v1_api_documentation_handler : ApiDocumentationHandler
      ApiDocumentationHandler.new("/", "/index.html")
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
        when M_TYPE_CHORD_BROADCAST_NODE_JOINED
          _broadcast_node_joined(socket, message_content)
        when M_TYPE_NODE_REQUEST_VALIDATION_CHALLENGE
          _request_validation_challenge(socket, message_content)
        when M_TYPE_NODE_RECEIVE_VALIDATION_CHALLENGE
          _receive_validation_challenge(socket, message_content)
        when M_TYPE_NODE_REQUEST_VALIDATION_CHALLENGE_CHECK
          _request_validation_challenge_check(socket, message_content)
        when M_TYPE_NODE_REQUEST_VALIDATION_SUCCESS
          _request_validation_success(socket, message_content)
        when M_TYPE_NODE_REQUEST_CHAIN_SIZE
          _request_chain_size(socket, message_content)
        when M_TYPE_NODE_RECEIVE_CHAIN_SIZE
          _receive_chain_size(socket, message_content)
        when M_TYPE_NODE_REQUEST_CHAIN
          _request_chain(socket, message_content)
        when M_TYPE_NODE_RECEIVE_CHAIN
          _receive_chain(socket, message_content)
        when M_TYPE_NODE_BROADCAST_TRANSACTION
          _broadcast_transaction(socket, message_content)
        when M_TYPE_NODE_BROADCAST_BLOCK
          _broadcast_block(socket, message_content)
        when M_TYPE_NODE_REQUEST_TRANSACTIONS
          _request_transactions(socket, message_content)
        when M_TYPE_NODE_RECEIVE_TRANSACTIONS
          _receive_transactions(socket, message_content)
        when M_TYPE_NODE_BROADCAST_MINER_NONCE
          _broadcast_miner_nonce(socket, message_content)
        when M_TYPE_NODE_REQUEST_MINER_NONCES
          _request_miner_nonces(socket, message_content)
        when M_TYPE_NODE_RECEIVE_MINER_NONCES
          _receive_miner_nonces(socket, message_content)
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
      debug "new #{transaction.kind} transaction coming: #{transaction.short_id}"

      send_transaction(transaction, from)

      @blockchain.add_transaction(transaction)
    end

    # ----- miner nonces -----
    private def _broadcast_miner_nonce(socket, _content)
      return unless @phase == SetupPhase::DONE

      _m_content = MContentNodeBroadcastMinerNonce.from_json(_content)

      miner_nonce = _m_content.nonce
      from = _m_content.from

      debug "new miner nonce coming: #{miner_nonce.value} from node: #{miner_nonce.node_id} for address: #{miner_nonce.address}"

      send_miner_nonce(miner_nonce, from)
      @blockchain.add_miner_nonce(miner_nonce)
    end

    def send_miner_nonce(miner_nonce : MinerNonce, from : Chord::NodeContext? = nil)
      content = if from.nil? || (!from.nil? && from[:is_private])
                  {nonce: miner_nonce, from: @chord.context}
                else
                  {nonce: miner_nonce, from: from}
                end

      send_on_chord(M_TYPE_NODE_BROADCAST_MINER_NONCE, content, from)
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
      content = if from.nil? || (!from.nil? && from[:is_private])
                  {nodes: joined_nodes, from: @chord.context}
                else
                  {nodes: joined_nodes, from: from}
                end

      send_on_chord(M_TYPE_CHORD_BROADCAST_NODE_JOINED, content, from)
    end

    # ----- blocks -----

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
      info "New #{block.kind} block coming from peer with index: #{block.index}"
      case block
      when SlowBlock then broadcast_slow_block(socket, block, from)
      when FastBlock then broadcast_fast_block(socket, block, from)
      end
    end

    private def broadcast_slow_block(socket : HTTP::WebSocket, block : SlowBlock, from : Chord::NodeContext? = nil)
      # random_secs = Random.rand(30)
      # warning "++++++++++++ sleeping #{random_secs} seconds before sending to try to cause chaos....."
      # warning "++++++++++++ sleeping 2 minutes before sending to try to cause chaos....."
      # sleep(Time::Span.new(seconds: random_secs))
      # sleep(120)
      # warning "++++++++++++ finished sleeping"

      latest_slow = get_latest_slow_from_db
      has_block = @blockchain.database.get_block(block.index)
      latest_local_fast_index = get_latest_fast_index
      slow_sync = SlowSync.new(block, @blockchain.mining_block, (has_block.nil? ? nil : has_block.not_nil!.as(SlowBlock)), latest_slow)
      state = slow_sync.process

      case state
      when SlowSyncState::CREATE
        execute_create(socket, block, latest_slow, latest_local_fast_index, from)
      when SlowSyncState::REPLACE
        execute_replace(socket, block, latest_slow, latest_local_fast_index, from)
      when SlowSyncState::REJECT_OLD
        execute_reject(socket, block, latest_slow, RejectBlockReason::OLD, from)
      when SlowSyncState::REJECT_VERY_OLD
        execute_reject(socket, block, latest_slow, RejectBlockReason::VERY_OLD, from)
      when SlowSyncState::SYNC
        execute_sync(socket, block, latest_slow, from)
      else
        raise "Error - unknown SlowSyncState: #{state}"
      end
    rescue e : Exception
      error (e.message || "broadcast_slow_block unknown error: #{e.inspect}")
    ensure
      send_block(block, from)
    end

    private def get_latest_slow_from_db : SlowBlock
      blocks = @blockchain.database.get_highest_block_for_kind(BlockKind::SLOW)
      blocks.size > 0 ? blocks.first.as(SlowBlock) : raise "Node::get_latest_slow_from_db: no slow blocks found in database"
    end

    private def sync_chain_on_error(conflicted_index : Int64, latest_local_slow_index : Int64, latest_local_fast_index : Int64, count : Int32, socket : HTTP::WebSocket)
      if conflicted_index.even?
        slow_index = @blockchain.database.lowest_slow_index_after_slow_block(latest_local_slow_index - count) || latest_local_slow_index
        fast_index = @blockchain.database.lowest_fast_index_after_slow_block(slow_index) || latest_local_fast_index

        warning "(slow) sync_chain_on_error: attempting to re-sync from failed slow block #{conflicted_index} with slow_index: #{slow_index}, fast_index: #{fast_index}"
        sync_chain_from_point(slow_index, fast_index, socket)
      else
        fast_index = @blockchain.database.lowest_fast_index_after_fast_block(latest_local_fast_index - count) || latest_local_fast_index
        slow_index = @blockchain.database.lowest_slow_index_after_fast_block(fast_index) || latest_local_slow_index

        warning "(fast) sync_chain_on_error: attempting to re-sync from failed fast block #{conflicted_index} with slow_index: #{slow_index}, fast_index: #{fast_index}"
        sync_chain_from_point(slow_index, fast_index, socket)
      end
    end

    private def execute_create(socket : HTTP::WebSocket, block : SlowBlock, latest_slow : SlowBlock, latest_local_fast_index : Int64, from : Chord::NodeContext?)
      info "received block: #{block.index} from peer that I don't have in my db"

      # random_secs = Random.rand(30)
      # warning "++++++++++++ sleeping #{random_secs} seconds before sending to try to cause chaos....."
      # sleep(Time::Span.new(seconds: random_secs))
      # warning "++++++++++++ finished sleeping"

      if _block = @blockchain.valid_block?(block, false, true)
        info "received block: #{_block.index} was valid so storing in my db"
        debug "slow: finished sending new block on to peer"
        @miners_manager.forget_most_difficult
        debug "slow: about to create the new block locally"
        new_block(_block)

        info "#{magenta("NEW SLOW BLOCK broadcasted")}: #{light_green(_block.index)} at difficulty: #{light_cyan(_block.difficulty)}"
      end
    rescue e : Exception
      warning "received block: #{block.index} from peer that I don't have in my db was invalid - so keeping my local and re-syncing"
      warning "error was: #{e.message || "unknown error"}"

      sync_chain_on_error(block.index, latest_slow.index, latest_local_fast_index, 2, socket)
    end

    private def execute_replace(socket : HTTP::WebSocket, block : SlowBlock, latest_slow : SlowBlock, latest_local_fast_index : Int64, from : Chord::NodeContext?)
      warning "slow: blockchain conflicted at incoming #{block.index} and local (#{light_cyan(latest_slow.index)})"
      warning "slow: local timestamp: #{latest_slow.timestamp}, arriving block timestamp: #{block.timestamp}"
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
      warning "arriving block #{block.index} failed validity check, we can't make it our local latest - so keeping my local and re-syncing"
      warning "error was: #{e.message || "unknown error"}"

      sync_chain_on_error(block.index, latest_slow.index, latest_local_fast_index, 2, socket)
    end

    private def execute_reject(socket : HTTP::WebSocket, block : SlowBlock, latest_slow : SlowBlock, reason : RejectBlockReason, from : Chord::NodeContext?)
      case reason
      when RejectBlockReason::OLD
        warning "slow: blockchain conflicted at incoming #{block.index} and local (#{light_cyan(latest_slow.index)})"
        warning "slow: local timestamp: #{latest_slow.timestamp}, arriving block timestamp: #{block.timestamp}"
        warning "keeping our local block: #{latest_slow.index} and ignoring the block: #{block.index} because local one was minted first or (at the same time but with identical hash)"
      when RejectBlockReason::VERY_OLD
        warning "ignore very old block: #{block.index} because local latest is: #{latest_slow.index}"
      else
        warning "unknown rejection reason #{reason} - so ignoring it"
      end
    end

    private def execute_sync(socket : HTTP::WebSocket, block : SlowBlock, latest_slow : SlowBlock, from : Chord::NodeContext?)
      warning "slow: require new chain after - local: #{latest_slow.index} for incoming from peer: #{block.index}"
      sync_chain(socket, false)
    end

    def fast_block_was_signed_by_official_fast_node?(block : FastBlock) : Bool
      debug "verifying fast block was signed by official fast node"
      hash_salt = block.hash
      signature = block.signature
      address = block.address
      public_key = block.public_key
      @blockchain.official_node.i_am_a_fastnode?(address) && KeyUtils.verify_signature(hash_salt, signature, public_key)
    end

    # There is only 1 fast node on the network in phase 1 - so use this simple logic until that changes
    private def broadcast_fast_block(socket : HTTP::WebSocket, block : FastBlock, from : Chord::NodeContext? = nil)
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

    def new_block(block : SlowBlock | FastBlock)
      case block
      when SlowBlock then @blockchain.push_slow_block(block)
      when FastBlock then @blockchain.push_fast_block(block)
      end

      @pubsub_controller.broadcast_latest_block
      @wallet_info_controller.update_wallet_information(block.transactions)
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

    # on the parent
    private def _request_validation_challenge(socket, _content)
      _m_content = MContentNodeRequestValidationChallenge.from_json(_content)

      remote_slow_index = _m_content.latest_slow_index
      remote_fast_index = _m_content.latest_fast_index

      info "requested validation challenge with latest slow index: #{remote_slow_index} , latest fast index: #{remote_fast_index}"

      if remote_slow_index == 0_i64 && remote_fast_index == 0_i64
        # child has no blocks so bypass validation check
        info "validation challenge expedited as challenger has no blocks"
        send(socket, M_TYPE_NODE_REQUEST_VALIDATION_SUCCESS, {} of String => String)
      else
        # tell child about blocks to validate based on a window of blocks
        # first 50 on parent, random percent in middle, then 50 last blocks capped at the highest child blocks
        local_slow_index = @blockchain.database.highest_index_of_kind(BlockKind::SLOW)
        local_fast_index = @blockchain.database.highest_index_of_kind(BlockKind::FAST)

        validation_slow_index = Math.min(remote_slow_index, local_slow_index)
        validation_fast_index = Math.min(remote_fast_index, local_fast_index)

        validation_blocks = @blockchain.get_validation_block_ids(validation_slow_index, validation_fast_index, @security_level_percentage)
        @validation_hash = @blockchain.get_hash_of_block_hashes(validation_blocks)

        info "validation challenge proceeding..."
        send(socket, M_TYPE_NODE_RECEIVE_VALIDATION_CHALLENGE, {validation_blocks: validation_blocks})
      end

      target_slow_index = @blockchain.database.highest_index_of_kind(BlockKind::SLOW)
      target_fast_index = @blockchain.database.highest_index_of_kind(BlockKind::FAST)

      if ((remote_slow_index > target_slow_index) || (remote_fast_index > target_fast_index))
        info "(request validation challenge) Remote indices were higher local indices so starting chain sync."
        info "Remote slow: #{remote_slow_index}, target slow: #{target_slow_index}"
        info "Remote fast: #{remote_fast_index}, target fast: #{target_fast_index}"
        sync_chain(socket, false)
      end
    end

    # on the child
    private def _receive_validation_challenge(socket, _content)
      _m_content = MContentNodeReceiveValidationChallenge.from_json(_content)

      validation_blocks = _m_content.validation_blocks

      info "received validation challenge from remote node"

      local_validation_hash = @blockchain.get_hash_of_block_hashes(validation_blocks)

      send(socket, M_TYPE_NODE_REQUEST_VALIDATION_CHALLENGE_CHECK, {validation_hash: local_validation_hash})
    end

    # on the parent
    private def _request_validation_challenge_check(socket, _content)
      _m_content = MContentNodeRequestValidationChallengeCheck.from_json(_content)
      # validation_hash = _m_content.validation_hash

      debug "checking validation challenge hash from connecting node"

      # if validation_hash == @validation_hash
      info "validation hash succesfully confirmed so informing connecting node"
      send(socket, M_TYPE_NODE_REQUEST_VALIDATION_SUCCESS, {} of String => String)
      # else
      #   warning "validation hash failed so rejecting connection ..."
      #   send(socket, M_TYPE_CHORD_JOIN_REJECTED, {reason: "Database validation failed: your data is not compatible with our data!"})
      # end
    end

    # on the child
    private def _request_validation_success(socket, _content)
      info "validation hash successfuly validated - proceed to sync"
      latest_slow_index = get_latest_slow_index
      latest_fast_index = get_latest_fast_index

      slow_sync_index = latest_slow_index
      fast_sync_index = latest_fast_index
      send(socket, M_TYPE_NODE_REQUEST_CHAIN_SIZE, {chunk_size: @sync_chunk_size, latest_slow_index: slow_sync_index, latest_fast_index: fast_sync_index})
    end

    # on the parent
    private def _request_chain_size(socket, _content)
      _m_content = MContentNodeRequestChainSize.from_json(_content)

      remote_slow_index = _m_content.latest_slow_index
      remote_fast_index = _m_content.latest_fast_index
      chunk_size = _m_content.chunk_size

      debug "requested new chain size with latest slow index: #{remote_slow_index} , latest fast index: #{remote_fast_index}"

      target_slow_index = @blockchain.database.highest_index_of_kind(BlockKind::SLOW)
      target_fast_index = @blockchain.database.highest_index_of_kind(BlockKind::FAST)

      debug "sending with chunk size: #{@sync_chunk_size}"
      send(socket, M_TYPE_NODE_RECEIVE_CHAIN_SIZE, {chunk_size: chunk_size, slowchain_start_index: remote_slow_index, fastchain_start_index: remote_fast_index, slow_target_index: target_slow_index, fast_target_index: target_fast_index})

      if ((remote_slow_index > target_slow_index) || (remote_fast_index > target_fast_index))
        info "(request chain size) Remote indices were higher local indices so starting chain sync."
        info "Remote slow: #{remote_slow_index}, target slow: #{target_slow_index}"
        info "Remote fast: #{remote_fast_index}, target fast: #{target_fast_index}"
        sync_chain(socket, false)
      end
    end

    # on the child
    private def _receive_chain_size(socket, _content)
      _m_content = MContentNodeReceiveChainSize.from_json(_content)

      _remote_slow_start_index = _m_content.slowchain_start_index
      _remote_fast_start_index = _m_content.fastchain_start_index

      @sync_slow_blocks_target_index = _m_content.slow_target_index
      @sync_fast_blocks_target_index = _m_content.fast_target_index

      chunk_size = _m_content.chunk_size

      latest_local_slow_index = @blockchain.database.highest_index_of_kind(BlockKind::SLOW)
      latest_local_fast_index = @blockchain.database.highest_index_of_kind(BlockKind::FAST)

      # if there are no blocks then set to -1 to force sync the genesis block from peer
      latest_local_slow_index = -1_i64 if latest_local_slow_index == 0_i64
      latest_local_fast_index = -1_i64 if latest_local_fast_index == 0_i64

      if latest_local_slow_index >= @sync_slow_blocks_target_index && latest_local_fast_index >= @sync_fast_blocks_target_index
        # nothing to sync so proceed to transaction syncing
        info "no blocks to sync to moving onto transaction sync"
        if @phase == SetupPhase::BLOCKCHAIN_SYNCING
          @phase = SetupPhase::TRANSACTION_SYNCING
          proceed_setup
        end
      else
        send(socket, M_TYPE_NODE_REQUEST_CHAIN, {start_slow_index: _remote_slow_start_index, chunk_size: chunk_size, start_fast_index: _remote_fast_start_index})
      end
    end

    # on the parent
    private def _request_chain(socket, _content)
      _m_content = MContentNodeRequestChain.from_json(_content)

      remote_start_slow_index = _m_content.start_slow_index
      remote_start_fast_index = _m_content.start_fast_index

      chunk_size = _m_content.chunk_size

      debug "requested new chain slow start index: #{remote_start_slow_index} with chunk #{chunk_size} , latest fast index: #{remote_start_fast_index} with chunk #{chunk_size}"

      ids = subchain_algo(remote_start_slow_index, remote_start_fast_index, chunk_size)
      blocks = @blockchain.database.get_blocks_by_ids(ids)

      send(socket, M_TYPE_NODE_RECEIVE_CHAIN, {blocks: blocks, chunk_size: chunk_size})
      debug "chain sent to peer for sync"

      latest_local_slow_index = @blockchain.database.highest_index_of_kind(BlockKind::SLOW)
      latest_local_fast_index = @blockchain.database.highest_index_of_kind(BlockKind::FAST)

      if ((remote_start_slow_index > latest_local_slow_index) || (remote_start_fast_index > latest_local_fast_index))
        info "(request chain) Remote indices were higher local indices so starting chain sync."
        info "Remote slow: #{remote_start_slow_index}, target slow: #{latest_local_slow_index}"
        info "Remote fast: #{remote_start_fast_index}, target fast: #{latest_local_fast_index}"
        sync_chain(socket, false)
      end
    end

    # on child
    # ameba:disable Metrics/CyclomaticComplexity
    private def _receive_chain(socket, _content)
      _m_content = MContentNodeReceiveChain.from_json(_content)

      _remote_chain = _m_content.blocks
      chunk_size = _m_content.chunk_size

      _remote_slow_chain = _remote_chain.nil? ? nil : _remote_chain.not_nil!.select(&.is_slow_block?)
      _remote_fast_chain = _remote_chain.nil? ? nil : _remote_chain.not_nil!.select(&.is_fast_block?)

      if remote_slow_chain = _remote_slow_chain
        info "received #{remote_slow_chain.size} SLOW blocks"
      else
        info "received empty SLOW chain"
      end

      if remote_fast_chain = _remote_fast_chain
        info "received #{remote_fast_chain.size} FAST blocks"
      else
        info "received empty FAST chain"
      end

      previous_local_slow_index = @blockchain.database.highest_index_of_kind(BlockKind::SLOW)
      previous_local_fast_index = @blockchain.database.highest_index_of_kind(BlockKind::FAST)

      replace_result = @blockchain.replace_mixed_chain(_remote_chain)
      if replace_result.success
        latest_local_slow_index = @blockchain.database.highest_index_of_kind(BlockKind::SLOW)
        latest_local_fast_index = @blockchain.database.highest_index_of_kind(BlockKind::FAST)

        info "slow: chain updated: #{light_green(previous_local_slow_index)} -> #{light_green(latest_local_slow_index)}"
        info "fast: chain updated: #{light_green(previous_local_fast_index)} -> #{light_green(latest_local_fast_index)}"

        @miners_manager.broadcast
      end

      latest_local_slow_index = @blockchain.database.highest_index_of_kind(BlockKind::SLOW)
      latest_local_fast_index = @blockchain.database.highest_index_of_kind(BlockKind::FAST)

      info "checking if still need to sync: slow #{light_yellow(latest_local_slow_index)}/#{light_blue(@sync_slow_blocks_target_index)} fast #{light_yellow(latest_local_fast_index)}/#{light_blue(@sync_fast_blocks_target_index)}"
      sync_required = latest_local_slow_index < @sync_slow_blocks_target_index || latest_local_fast_index < @sync_fast_blocks_target_index

      if sync_required && !@sync_giving_up
        warning "yes - still need to sync"
        if replace_result.success
          info "mixed chain was replaced earlier ok so requesting another sync"
          send(socket, M_TYPE_NODE_REQUEST_CHAIN, {start_slow_index: latest_local_slow_index, chunk_size: chunk_size, start_fast_index: latest_local_fast_index})
        elsif !replace_result.success && @sync_retry_1_count < MAX_SYNC_RETRY
          @sync_retry_1_count += 2
          warning "failed to replace mixed chain at: #{replace_result.index} so starting a decremental retry at (#{@sync_retry_1_count}/#{MAX_SYNC_RETRY})"
          sync_chain_on_error(replace_result.index, latest_local_slow_index, latest_local_fast_index, @sync_retry_1_count, socket)
        elsif !replace_result.success && @sync_retry_2_count < MAX_SYNC_RETRY
          warning "can't recover giving up"
          @giving_up = true
          # @sync_retry_2_count += 2
          # warning "failed to re-sync mixed chain from at: #{replace_result.index} so starting retry with another peer at (#{@sync_retry_1_count}/#{MAX_SYNC_RETRY})"
          # # get a socket
          # sync_chain_on_error(replace_result.index, latest_local_slow_index, latest_local_fast_index, @sync_retry_1_count, socket)
        else
          warning "can't recover giving up"
          @giving_up = true
        end
      elsif sync_required && @sync_giving_up
        # we were unable to get back in sync
        @sync_retry_1_count = 0
        @sync_retry_2_count = 0
        @sync_giving_up = false

        warning "chain failed to fully sync - but moving on to transaction syncing anyway"
        # if no more to sync then move onto phase transaction syncing
        if @phase == SetupPhase::BLOCKCHAIN_SYNCING
          @phase = SetupPhase::TRANSACTION_SYNCING
          proceed_setup
        end
      else
        @sync_retry_1_count = 0
        @sync_retry_2_count = 0
        @sync_giving_up = false

        info "chain fully synced so moving on to transaction syncing"
        # if no more to sync then move onto phase transaction syncing
        if @phase == SetupPhase::BLOCKCHAIN_SYNCING
          @phase = SetupPhase::TRANSACTION_SYNCING
          proceed_setup
        end
      end
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
        @phase = SetupPhase::MINER_NONCE_SYNCING
        proceed_setup
      end
    end

    private def _request_miner_nonces(socket, _content)
      MContentNodeRequestMinerNonces.from_json(_content)

      info "requested miner nonces"

      miner_nonces = @blockchain.pending_miner_nonces
      send(
        socket,
        M_TYPE_NODE_RECEIVE_MINER_NONCES,
        {
          nonces: miner_nonces,
        }
      )
    end

    private def _receive_miner_nonces(socket, _content)
      _m_content = MContentNodeReceiveMinerNonces.from_json(_content)

      miner_nonces = _m_content.nonces

      info "received #{miner_nonces.size} MINER NONCES"

      @blockchain.replace_miner_nonces(miner_nonces)

      if @phase == SetupPhase::MINER_NONCE_SYNCING
        @phase = SetupPhase::PRE_DONE
        proceed_setup
      end
    end

    private def handlers
      [
        peer_handler,
        Defense::Handler.new,
        @rpc_controller.get_handler,
        @rest_controller.get_handler,
        @pubsub_controller.get_handler,
        @wallet_info_controller.get_handler,
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

      if @blockchain.has_no_blocks?
        info "There were no blocks in the database - "
        @phase = SetupPhase::CONNECTING_NODES
        proceed_setup
      else
        info "loaded blockchain's total size: #{light_cyan(@blockchain.chain.size)}"
        info "highest slow block index: #{light_cyan(@blockchain.latest_slow_block.index)}"
        info "highest fast block index: #{light_cyan(@blockchain.latest_fast_block_index_or_zero)}"

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
        @phase = SetupPhase::BLOCKCHAIN_LOADING
        proceed_setup
      when SetupPhase::BLOCKCHAIN_LOADING
        load_blockchain_from_database
      when SetupPhase::CONNECTING_NODES
        setup_connectivity
      when SetupPhase::BLOCKCHAIN_SYNCING
        sync_chain
      when SetupPhase::TRANSACTION_SYNCING
        sync_transactions
      when SetupPhase::MINER_NONCE_SYNCING
        sync_miner_nonces
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
