module ::Sushi::Core
  class Miner
    @wallet      : Wallet
    @latest_hash : String?
    @difficulty  : Int32 = 0

    def initialize(@is_testnet : Bool, @host : String, @port : Int32, @wallet : Wallet)
    end

    def pow : UInt64
      nonce : UInt64 = Random.rand(UInt64::MAX)

      info "starting nonce from #{light_cyan(nonce)}"

      latest_nonce = nonce
      latest_time = Time.now

      loop do
        next if @difficulty == 0
        next unless latest_hash = @latest_hash

        break if valid?(latest_hash, nonce, @difficulty)

        nonce += 1

        if nonce%100000 == 0
          time_now = Time.now
          time_diff = (time_now - latest_time).total_seconds

          next if time_diff == 0

          hash_rate = (nonce - latest_nonce)/time_diff

          info "#{nonce - latest_nonce} hashes, #{hash_rate_with_unit(hash_rate)}"

          latest_nonce = nonce
          latest_time = time_now
        end
      end

      info "found new nonce: #{light_cyan(nonce)}"

      nonce
    end

    def run
      socket = HTTP::WebSocket.new(@host, "peer", @port)
      socket.on_message do |message|

        message_json = JSON.parse(message)
        message_type = message_json["type"].as_i
        message_content = message_json["content"].to_s

        case message_type
        when M_TYPE_HANDSHAKE_MINER_ACCEPTED
          _handshake_miner_accepted(socket, message_content)
        when M_TYPE_HANDSHAKE_MINER_REJECTED
          _handshake_miner_rejected(socket, message_content)
        when M_TYPE_BLOCK_UPDATE
          _block_update(socket, message_content)
        end
      end

      send(socket, M_TYPE_HANDSHAKE_MINER, { address: @wallet.address })

      Thread.new do
        while nonce = pow
          send(socket, M_TYPE_FOUND_NONCE, { nonce: nonce }) unless socket.closed?
        end
      end

      socket.run
    end

    private def _handshake_miner_accepted(socket, _content)
      _m_content = M_CONTENT_HANDSHAKE_MINER_ACCEPTED.from_json(_content)

      @difficulty = _m_content.difficulty
      @latest_hash = _m_content.block.to_hash

      info "handshake has been accepted"
      info "set difficulty: #{light_cyan(@difficulty)}"
      info "set latest hash: #{light_green(@latest_hash)}"
    end

    private def _handshake_miner_rejected(socket, _content)
      _m_content = M_CONTENT_HANDSHAKE_MINER_REJECTED.from_json(_content)

      reason = _m_content.reason

      error "handshake failed for the reason;"
      error reason
    end

    private def _block_update(socket, _content)
      _m_content = M_CONTENT_BLOCK_UPDATE.from_json(_content)

      latest_block = _m_content.block
      @latest_hash = latest_block.to_hash

      info "latest block has been updated"
      info "set latest_hash: #{light_green(@latest_hash)}"
    end

    private def hash_rate_with_unit(hash_rate : Float64) : String
      return "#{hash_rate.to_i} [H/s]" if hash_rate / 1000.0 <= 1.0
      return "#{(hash_rate/1000.0).to_i} [KH/s]" if hash_rate / 1000000.0 <= 1.0
      return "#{(hash_rate/1000000.0).to_i} [MH/s]" if hash_rate / 1000000000.0 <= 1.0
      "#{(hash_rate/1000000000.0).to_i} [GH/s]"
    end

    include Logger
    include Protocol
    include Consensus
    include Common::Color
  end
end
