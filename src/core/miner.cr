module ::Garnet::Core
  class Miner
    @wallet : Wallet
    @last_hash : String?

    def initialize(@host : String, @port : Int32, wallet_path : String)
      @wallet = Wallet.from_path(wallet_path)
    end

    def pow : UInt64
      nonce : UInt64 = 0_u64

      last_nonce = nonce
      last_time = Time.now

      loop do
        next unless last_hash = @last_hash

        break if Core::Block.valid_nonce?(last_hash, nonce)

        nonce += 1

        if nonce%100000 == 0
          time_now = Time.now
          time_diff = (time_now - last_time).total_seconds

          next if time_diff == 0

          hash_rate = ((nonce - last_nonce)/time_diff).to_i

          info "Hash Rate: #{hash_rate} [H/s]"

          last_nonce = nonce
          last_time = time_now
        end
      end

      info "Found new nonce! #{light_cyan(nonce)}"

      nonce
    end

    def run
      web_socket = HTTP::WebSocket.new(@host, "peer", @port)
      web_socket.on_message do |msg|
        last_block = Core::Block.from_json(msg)
        @last_hash = last_block.to_hash

        info "Last block has been updated"
        info light_green(@last_hash)
      end

      send(web_socket, M_TYPE_HANDSHAKE_MINER, { address: @wallet.address })

      Thread.new do
        while nonce = pow
          send(web_socket, M_TYPE_FOUND_NONCE, { nonce: nonce }) unless web_socket.closed?
        end
      end

      web_socket.run
    end

    include Logger
    include Protocol
    include Common::Color
  end
end
