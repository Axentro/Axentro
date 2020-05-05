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
    @mid : String = HumanHash.uuid.digest
    @terminate : Channel(Nil) = Channel(Nil).new
    @workers : Array(MultiProcess::Worker) = [] of MultiProcess::Worker

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

      block = _m_content.block
      difficulty = _m_content.difficulty

      info "handshake has been accepted"

      debug "set difficulty: #{light_cyan(difficulty)}"
      debug "set block: #{light_green(block.index)}"

      start_mining_with_multiple_fibers(difficulty, block)
      # start_workers(difficulty, block)
    end

    private def _handshake_miner_rejected(_content)
      _m_content = MContentMinerHandshakeRejected.from_json(_content)

      reason = _m_content.reason

      error "handshake failed because:"
      error reason
    end

    private def _block_update(_content)
      _m_content = MContentMinerBlockUpdate.from_json(_content)

      block = _m_content.block
      difficulty = _m_content.difficulty

      info "#{magenta("PREPARING NEXT SLOW BLOCK")}: #{light_green(block.index)} at approximate difficulty: #{light_cyan(block.difficulty)}"

      debug "set difficulty: #{light_cyan(difficulty)}"
      debug "set block: #{light_green(block.index)}"

      # clean_workers
      @terminate.close
      
      start_mining_with_multiple_fibers(difficulty, block)
      # start_workers(difficulty, block)
    end

    def clean_connection(socket)
      # clean_workers

      error "the connection to the node has been closed"
      error "exit the mining process with -1"
      exit -1
    end

    #  ---
    # 1. when the miner handshake succeeds then start a number of workers on mining
    # 2. when one of the miners finds a valid nonce it should send it to the main miner process to be sent on to the node
    # 3. when a block update arrives - all workers should either die and new workers start up (or the existing workers get a new task)
    #  ---

    def start_mining_with_multiple_fibers(difficulty, block)
      # create all workers
      @terminate = Channel(Nil).new
      local_terminate = @terminate
      res_channels = (1..@num_processes).map do |n|
        result = Channel(MinerNonce).new
        spawn(name: "worker_#{n}") do
          loop do
            break if local_terminate.closed?
            debug "inside worker: #{Fiber.current.name}"
            message = {start_nonce: Random.rand(UInt64::MAX).to_s, difficulty: difficulty, block: block}
            miner_nonce = MinerWorker.new.task(message, local_terminate)
            debug "NONCE FOUND: by #{Fiber.current.name}"
            result.send(miner_nonce.not_nil!)
          end
        end
        result
      end
      debug "#{Fiber.current.name}: done spawning fibers"
      loop do
        break if local_terminate.closed?
        miner_nonce = Channel.receive_first(res_channels)
        nonce_with_address_json = {nonce: miner_nonce.with_address(@wallet.address)}.to_json
        send(socket, M_TYPE_MINER_FOUND_NONCE, MContentMinerFoundNonce.from_json(nonce_with_address_json))
      end
      # res_channels.each do |result|
      #   miner_nonce = result.receive
      #   nonce_with_address_json = {nonce: miner_nonce.with_address(@wallet.address)}.to_json
      #   send(socket, M_TYPE_MINER_FOUND_NONCE, MContentMinerFoundNonce.from_json(nonce_with_address_json))
      # end

      # receive from a worker and send to node

    end

    # def start_workers(difficulty, block)
    #   @workers = MinerWorker.create(@num_processes)
    #   @workers.each do |w|
    #     spawn do
    #       loop do
    #         nonce_found_message = w.receive.try &.to_s || "error"

    #         debug "received nonce #{nonce_found_message} from worker"

    #         unless nonce_found_message == "error"
    #           nonce_with_address_json = {nonce: MinerNonce.from_json(nonce_found_message).with_address(@wallet.address)}.to_json
    #           send(socket, M_TYPE_MINER_FOUND_NONCE, MContentMinerFoundNonce.from_json(nonce_with_address_json))
    #         end

    #         update(w, difficulty, block)
    #       rescue ioe : IO::EOFError
    #         warning "received invalid message. will be ignored"
    #       end
    #     end
    #   end

    #   update(difficulty, block)
    # end

    # def update(difficulty, block)
    #   debug "update new workers"

    #   @workers.each do |w|
    #     update(w, difficulty, block)
    #   end
    # end

    # def update(worker, difficulty, block)
    #   worker.exec({start_nonce: Random.rand(UInt64::MAX).to_s, difficulty: difficulty, block: block}.to_json)
    # end

    # def clean_workers
    #   debug "clean workers"
    #   @workers.each(&.kill)
    # end

    include Logger
    include Protocol
    include Common::Color
    include NonceModels
  end
end
