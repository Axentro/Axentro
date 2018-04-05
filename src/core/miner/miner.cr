module ::Sushi::Core
  class Miner
    @wallet : Wallet
    @difficulty : Int32 = 0
    @latest_block : Block?
    @latest_hash : String?
    @latest_nonce : UInt64 = 0_u64 # for debug
    @threads = [] of Thread
    @use_ssl : Bool

    def initialize(@is_testnet : Bool, @host : String, @port : Int32, @wallet : Wallet, @num_threads : Int32, @use_ssl : Bool)
      info "launching #{@num_threads} threads..."
    end

    def pow(thread : Int32) : UInt64
      nonce : UInt64 = Random.rand(UInt64::MAX)

      info "starting nonce from #{light_green(nonce)} (thread: #{thread + 1})"

      latest_nonce = nonce
      latest_time = Time.now
      @latest_nonce = nonce # for debug

      loop do
        next if @difficulty == 0
        next unless latest_block = @latest_block
        next unless latest_hash = @latest_hash

        break if valid?(latest_block.index, latest_hash, nonce, @difficulty)

        nonce += 1

        if nonce % 100 == 0
          time_now = Time.now
          time_diff = (time_now - latest_time).total_seconds

          next if time_diff == 0

          work_rate = (nonce - latest_nonce)/time_diff

          info "#{nonce - latest_nonce} works, #{work_rate_with_unit(work_rate)} (thread: #{thread + 1})"

          latest_nonce = nonce
          latest_time = time_now
        end
      rescue e : Exception
        error e.message.not_nil!
        error e.backtrace.join("\n")
        error "for nonce: #{@latest_nonce} (#{@latest_nonce.to_s(16)}, #{@latest_nonce.to_s(16).bytesize})"
        error "for hash: #{@latest_hash}"
      end

      info "found new nonce(#{@difficulty}): #{light_green(nonce)} (thread: #{thread + 1})"

      nonce
    end

    def run
      socket = HTTP::WebSocket.new(@host, "/peer", @port, @use_ssl)
      socket.on_message do |message|
        message_json = JSON.parse(message)
        message_type = message_json["type"].as_i
        message_content = message_json["content"].to_s

        case message_type
        when M_TYPE_MINER_HANDSHAKE_ACCEPTED
          _handshake_miner_accepted(socket, message_content)
        when M_TYPE_MINER_HANDSHAKE_REJECTED
          _handshake_miner_rejected(socket, message_content)
        when M_TYPE_MINER_BLOCK_UPDATE
          _block_update(socket, message_content)
        end
      end

      info "core version: #{light_green(Core::CORE_VERSION)}"

      send(socket, M_TYPE_MINER_HANDSHAKE, {
        version: Core::CORE_VERSION,
        address: @wallet.address,
      })

      @num_threads.times do |thread|
        @threads << Thread.new do
          while nonce = pow(thread)
            send(socket, M_TYPE_MINER_FOUND_NONCE, {nonce: nonce}) unless socket.closed?
          end
        end
      end

      socket.run
    end

    private def _handshake_miner_accepted(socket, _content)
      _m_content = M_CONTENT_MINER_HANDSHAKE_ACCEPTED.from_json(_content)

      @latest_block = _m_content.block
      @latest_hash = _m_content.block.to_hash
      @difficulty = _m_content.difficulty

      info "handshake has been accepted"
      info "set difficulty: #{light_cyan(@difficulty)}"
      info "set latest hash: #{light_green(@latest_hash)}"
    end

    private def _handshake_miner_rejected(socket, _content)
      _m_content = M_CONTENT_MINER_HANDSHAKE_REJECTED.from_json(_content)

      reason = _m_content.reason

      error "handshake failed for the reason;"
      error reason
    end

    private def _block_update(socket, _content)
      _m_content = M_CONTENT_MINER_BLOCK_UPDATE.from_json(_content)

      @latest_block = _m_content.block
      @latest_hash = _m_content.block.to_hash
      @difficulty = _m_content.difficulty

      info "latest block has been updated"
      info "set difficulty: #{light_cyan(@difficulty)}"
      info "set latest_hash: #{light_green(@latest_hash)}"
    end

    private def work_rate_with_unit(work_rate : Float64) : String
      return "#{work_rate.to_i} [Work/s]" if work_rate / 1000.0 <= 1.0
      return "#{(work_rate/1000.0).to_i} [KWork/s]" if work_rate / 1000000.0 <= 1.0
      return "#{(work_rate/1000000.0).to_i} [MWork/s]" if work_rate / 1000000000.0 <= 1.0
      "#{(work_rate/1000000000.0).to_i} [GWork/s]"
    end

    include Logger
    include Protocol
    include Consensus
    include Common::Color
  end
end
