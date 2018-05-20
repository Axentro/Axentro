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

module ::Sushi::Core
  class Miner < HandleSocket
    @wallet : Wallet
    @use_ssl : Bool

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
      })

      socket.run
    rescue e : Exception
      error "failed to start mining prosess"
      error e.message.not_nil!

      exit -1
    end

    private def socket
      @socket.not_nil!
    end

    private def _handshake_miner_accepted(_content)
      _m_content = M_CONTENT_MINER_HANDSHAKE_ACCEPTED.from_json(_content)

      latest_index = _m_content.block.index
      latest_hash = _m_content.block.to_hash
      difficulty = _m_content.difficulty

      info "handshake has been accepted"

      debug "set difficulty: #{light_cyan(difficulty)}"
      debug "set latest hash: #{light_green(latest_hash)}"

      start_workers(difficulty, latest_index, latest_hash)
    end

    private def _handshake_miner_rejected(_content)
      _m_content = M_CONTENT_MINER_HANDSHAKE_REJECTED.from_json(_content)

      reason = _m_content.reason

      error "handshake failed for the reason;"
      error reason
    end

    private def _block_update(_content)
      _m_content = M_CONTENT_MINER_BLOCK_UPDATE.from_json(_content)

      latest_index = _m_content.block.index
      latest_hash = _m_content.block.to_hash
      difficulty = _m_content.difficulty

      info "latest block has been updated"

      debug "set difficulty: #{light_cyan(difficulty)}"
      debug "set latest_hash: #{light_green(latest_hash)}"

      clean_workers

      start_workers(difficulty, latest_index, latest_hash)
    end

    def clean_connection(socket)
      clean_workers

      error "the connection to the node has been closed"
      error "exit the mining process with -1"
      exit -1
    end

    def start_workers(difficulty, latest_index, latest_hash)
      @workers = MinerWorker.create(@num_processes)
      @workers.each do |w|
        spawn do
          loop do
            nonce = w.receive.try &.to_u64 || -1

            debug "received nonce #{nonce} from worker"

            send(socket, M_TYPE_MINER_FOUND_NONCE, {nonce: nonce}) unless nonce == -1

            update(w, difficulty, latest_index, latest_hash)
          end
        end
      end

      update(difficulty, latest_index, latest_hash)
    end

    def update(difficulty, latest_index, latest_hash)
      debug "update new workers"

      @workers.each do |w|
        update(w, difficulty, latest_index, latest_hash)
      end
    end

    def update(worker, difficulty, latest_index, latest_hash)
      worker.exec({difficulty: difficulty, index: latest_index, hash: latest_hash}.to_json)
    end

    def clean_workers
      info "clean workers"
      @workers.each(&.kill)
    end

    include Logger
    include Protocol
    include Common::Color
  end
end
