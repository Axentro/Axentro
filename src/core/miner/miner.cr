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

module ::Axentro::Core
  class Miner < HandleSocket
    @wallet : Wallet
    @use_ssl : Bool
    @mid : String = HumanHash.uuid.digest

    @workers : Array(Tokoroten::Worker) = [] of Tokoroten::Worker

    def initialize(@is_testnet : Bool, @host : String, @port : Int32, @wallet : Wallet, @num_processes : Int32, @use_ssl : Bool)
      welcome

      info "launched #{@num_processes} processes..."
    end

    def run
      @socket = HTTP::WebSocket.new(@host, "/peer", @port, @use_ssl)

      socket.on_message do |message|
        message_json = JSON.parse(message)
        message_type = message_json["type"].as_i
        message_content = message_json["content"].to_s

        case message_type
        when M_TYPE_MINER_HANDSHAKE_ACCEPTED
          _handshake_miner_accepted(message_content)
        when M_TYPE_MINER_HANDSHAKE_REJECTED
          _handshake_miner_rejected(message_content)
        when M_TYPE_MINER_BLOCK_UPDATE
          _block_update(message_content)
        end
      rescue e : Exception
        warning "receive invalid message, will be ignored"
      end

      socket.on_close do |_|
        clean_connection(socket)
      end

      info "core version: #{light_green(Core::CORE_VERSION)}"

      send(socket, M_TYPE_MINER_HANDSHAKE, {
        version: Core::CORE_VERSION,
        address: @wallet.address,
        mid:     @mid,
      })

      socket.run
    rescue e : Exception
      error "failed to start mining process"
      error e.message.not_nil!

      exit -1
    end

    private def socket
      @socket.not_nil!
    end

    private def _handshake_miner_accepted(_content)
      _m_content = MContentMinerHandshakeAccepted.from_json(_content)

      block_index = _m_content.block_index
      block_hash = _m_content.block_hash
      difficulty = _m_content.difficulty

      info "handshake has been accepted"

      debug "set difficulty: #{light_cyan(difficulty)}"
      debug "set block index: #{light_green(block_index)}"
      debug "set block hash: #{light_green(block_hash)}"

      start_workers(difficulty, block_index, block_hash)
    end

    private def _handshake_miner_rejected(_content)
      _m_content = MContentMinerHandshakeRejected.from_json(_content)

      reason = _m_content.reason

      error "handshake failed because:"
      error reason
      exit -1
    end

    private def _block_update(_content)
      _m_content = MContentMinerBlockUpdate.from_json(_content)

      block_index = _m_content.block_index
      block_hash = _m_content.block_hash
      difficulty = _m_content.difficulty

      puts "MINER: #{block_hash}"
      # pp block

      info "#{magenta("PREPARING NEXT SLOW BLOCK")}: #{light_green(block_index)} at difficulty: #{light_cyan(difficulty)}, hash: #{block_hash}"

      debug "set difficulty: #{light_cyan(difficulty)}"
      debug "set block index: #{light_green(block_index)}"
      debug "set block hash: #{light_green(block_hash)}"

      clean_workers

      start_workers(difficulty, block_index, block_hash)
    end

    def clean_connection(socket)
      clean_workers

      error "the connection to the node has been closed"
      info "attempting to reconnect"
      run
    end

    def start_workers(difficulty, block_index, block_hash)
      @workers = MinerWorker.create(@num_processes)
      @workers.each do |w|
        spawn do
          loop do
            nonce_found_message = w.receive.try &.to_s || "error"

            debug "received nonce #{nonce_found_message} from worker"

            unless nonce_found_message == "error"
              nonce_with_address_json = {nonce: MinerNonce.from_json(nonce_found_message).with_address(@wallet.address).with_block_hash(block_hash)}.to_json
              send(socket, M_TYPE_MINER_FOUND_NONCE, MContentMinerFoundNonce.from_json(nonce_with_address_json))
            end

            update(w, difficulty, block_index, block_hash)
          rescue ioe : IO::EOFError
            warning "received invalid message. will be ignored"
          end
        end
      end

      update(difficulty, block_index, block_hash)
    end

    def update(difficulty, block_index, block_hash)
      debug "update new workers"

      @workers.each do |w|
        update(w, difficulty, block_index, block_hash)
      end
    end

    def update(worker, difficulty, block_index, block_hash)
      worker.exec({start_nonce: Random.rand(UInt64::MAX).to_s, difficulty: difficulty, block_index: block_index, block_hash: block_hash}.to_json)
    end

    def clean_workers
      debug "clean workers"
      @workers.each(&.kill)
    end

    include Logger
    include Protocol
    include Common::Color
    include NonceModels
  end
end
