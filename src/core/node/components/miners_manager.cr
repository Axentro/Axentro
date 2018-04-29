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

module ::Sushi::Core::NodeComponents
  class MinersManager
    alias Miner = NamedTuple(
      address: String,
      socket: HTTP::WebSocket,
      nonces: Array(UInt64),
    )

    alias Miners = Array(Miner)

    getter miners : Miners = Miners.new

    def initialize(@blockchain : Blockchain)
    end

    def handshake(node, socket, _content)
      return unless node.flag == FLAG_SETUP_DONE

      _m_content = M_CONTENT_MINER_HANDSHAKE.from_json(_content)

      version = _m_content.version
      address = _m_content.address

      if Core::CORE_VERSION > version
        return send(socket,
          M_TYPE_MINER_HANDSHAKE_REJECTED,
          {
            reason: "your sushim is out of date, please update it" +
                    "(node version: #{Core::CORE_VERSION}, miner version: #{version})",
          })
      end

      miner_network = Wallet.address_network_type(address)[:name]

      if miner_network != node.network_type
        warning "mismatch network type with miner #{address}"

        return send(socket, M_TYPE_MINER_HANDSHAKE_REJECTED, {
          reason: "network type mismatch",
        })
      end

      miner = {socket: socket, address: address, nonces: [] of UInt64}

      @miners << miner

      info "new miner: #{light_green(miner[:address][0..7])} (#{@miners.size})"

      send(socket, M_TYPE_MINER_HANDSHAKE_ACCEPTED, {
        version:    Core::CORE_VERSION,
        block:      @blockchain.latest_block,
        difficulty: miner_difficulty_at(@blockchain.latest_index),
      })
    rescue e : Exception
      warning "failed to execute handshake with new miner (disconnected)"
      warning e.message.not_nil! if e.message

      clean_connection(socket)
    end

    def found_nonce(node, socket, _content)
      return unless node.flag == FLAG_SETUP_DONE

      _m_content = M_CONTENT_MINER_FOUND_NONCE.from_json(_content)

      nonce = _m_content.nonce
      found = false

      if miner = find?(socket)
        if @miners.map { |m| m[:nonces] }.flatten.includes?(nonce)
          warning "nonce #{nonce} has already been discoverd"
        elsif !@blockchain.latest_block.valid_nonce?(nonce, miner_difficulty_at(@blockchain.latest_block.index))
          warning "received nonce is invalid, try to update latest block"

          begin
            send(miner[:socket], M_TYPE_MINER_BLOCK_UPDATE, {
              block:      @blockchain.latest_block,
              difficulty: miner_difficulty_at(@blockchain.latest_index),
            })
          rescue e : Exception
            warning "failed to update the block for a miner (disconnected)"

            clean_connection(miner[:socket])
          end
        else
          info "miner #{miner[:address][0..7]} found nonce (nonces: #{miner[:nonces].size})"

          miner[:nonces].push(nonce)

          found = true
        end
      end

      @blockchain.queue.enqueue(BlockQueue::TaskFoundNonce.new(self, nonce, @miners)) if found
    end

    def callback_from_queue(block)
      @blockchain.push_block(block)
      @blockchain.node.send_block(block)

      @miners.each do |m|
        m[:nonces].clear
      end

      broadcast_latest_block
    end

    def broadcast_latest_block
      @miners.each do |miner|
        begin
          send(miner[:socket], M_TYPE_MINER_BLOCK_UPDATE, {
            block:      @blockchain.latest_block,
            difficulty: miner_difficulty_at(@blockchain.latest_index),
          })
        rescue e : Exception
          warning "failed to update the block for a miner (disconnected)"

          clean_connection(miner[:socket])
        end
      end
    end

    def find?(socket : HTTP::WebSocket) : Miner?
      @miners.find { |m| m[:socket] == socket }
    end

    def clean_connection(socket)
      current_size = @miners.size
      @miners.reject! { |miner| miner[:socket] == socket }

      info "a miner has been removed. (#{@miners.size})" if current_size > @miners.size
    end

    def size
      @miners.size
    end

    include Logger
    include Protocol
    include Consensus
    include Common::Color
  end
end
