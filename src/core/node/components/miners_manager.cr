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
  class MinersManager < HandleSocket
    alias MinerContext = NamedTuple(
      address: String,
      nonces: Array(UInt64),
    )

    alias MinerContexts = Array(MinerContext)

    alias Miner = NamedTuple(
      context: MinerContext,
      socket: HTTP::WebSocket,
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

      miner_context = {address: address, nonces: [] of UInt64}
      miner = {context: miner_context, socket: socket}

      @miners << miner

      info "new miner: #{light_green(miner[:context][:address][0..7])} (#{@miners.size})"

      send(socket, M_TYPE_MINER_HANDSHAKE_ACCEPTED, {
        version:    Core::CORE_VERSION,
        block:      @blockchain.latest_block,
        difficulty: @blockchain.miner_difficulty_latest,
      })
    end

    def found_nonce(node, socket, _content)
      return unless node.flag == FLAG_SETUP_DONE

      _m_content = M_CONTENT_MINER_FOUND_NONCE.from_json(_content)

      nonce = _m_content.nonce
      found = false

      if miner = find?(socket)
        if @miners.map { |m| m[:context][:nonces] }.flatten.includes?(nonce)
          warning "nonce #{nonce} has already been discoverd"
        elsif !@blockchain.latest_block.valid_nonce?(nonce, @blockchain.miner_difficulty_latest)
          warning "received nonce is invalid, try to update latest block"

          send(miner[:socket], M_TYPE_MINER_BLOCK_UPDATE, {
            block:      @blockchain.latest_block,
            difficulty: @blockchain.miner_difficulty_latest,
          })
        else
          info "miner #{miner[:context][:address][0..7]} found nonce (nonces: #{miner[:context][:nonces].size})"
          miner[:context][:nonces].push(nonce)

          if block = @blockchain.valid_block?(nonce, @miners)
            node.new_block(block, true)
          end
        end
      end
    end

    def clear_nonces
      @miners.each do |m|
        m[:context][:nonces].clear
      end
    end

    def broadcast_latest_block
      info "new block difficulty: #{@blockchain.block_difficulty_latest}, " +
           "mining difficulty: #{@blockchain.miner_difficulty_latest}"

      @miners.each do |miner|
        send(miner[:socket], M_TYPE_MINER_BLOCK_UPDATE, {
          block:      @blockchain.latest_block,
          difficulty: @blockchain.miner_difficulty_latest,
        })
      end
    end

    def find?(socket : HTTP::WebSocket) : Miner?
      @miners.find { |m| m[:socket] == socket }
    end

    def clean_connection(socket)
      current_size = @miners.size
      @miners.reject! { |miner| miner[:socket] == socket }

      info "a miner has been removed. (#{current_size} -> #{@miners.size})" if current_size > @miners.size
    end

    def size
      @miners.size
    end

    def miner_contexts : MinerContexts
      @miners.map { |m| m[:context] }
    end

    include Protocol
    include Consensus
    include Common::Color
  end
end
