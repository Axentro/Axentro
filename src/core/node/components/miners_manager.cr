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
      mid: String
    )

    alias Miners = Array(Miner)

    @most_difficult_block_so_far : Block

    getter miners : Miners = Miners.new

    def initialize(@blockchain : Blockchain)
      @highest_difficulty_mined_so_far = 0
      @most_difficult_block_so_far = @blockchain.genesis_block
    end

    def handshake(socket, _content)
      return unless node.phase == SetupPhase::DONE

      verbose "requested handshake from a miner"

      _m_content = MContentMinerHandshake.from_json(_content)

      version = _m_content.version
      address = _m_content.address
      mid = _m_content.mid

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
      miner = {context: miner_context, socket: socket, mid: mid}

      @miners << miner

      miner_name = HumanHash.humanize(mid)
      info "new miner: #{light_green(miner_name)} (#{@miners.size})"

      send(socket, M_TYPE_MINER_HANDSHAKE_ACCEPTED, {
        version:    Core::CORE_VERSION,
        block:      @blockchain.mining_block,
        difficulty: @blockchain.mining_block_difficulty_miner,
      })
    end

    def found_nonce(socket, _content)
      return unless node.phase == SetupPhase::DONE

      verbose "miner sent a new nonce"

      _m_content = MContentMinerFoundNonce.from_json(_content)

      nonce = _m_content.nonce
      mined_timestamp = _m_content.timestamp

      debug "received a nonce of #{nonce} from a miner at timestamp #{mined_timestamp}"
      
      if miner = find?(socket)
        block = @blockchain.mining_block.with_nonce_and_mined_timestamp(nonce, mined_timestamp)

        debug "Received a freshly mined block..."
        block.to_s

        if @miners.map { |m| m[:context][:nonces] }.flatten.includes?(nonce)
          warning "nonce #{nonce} has already been discovered"
          return
        end

        mined_difficulty = block.valid_nonce?(@blockchain.mining_block_difficulty)
        if mined_difficulty < @blockchain.mining_block_difficulty_miner
          warning "received nonce is invalid, try to update latest block"
          debug "mined difficulty is: #{mined_difficulty}"

          send(miner[:socket], M_TYPE_MINER_BLOCK_UPDATE, {
            block:      @blockchain.mining_block,
            difficulty: @blockchain.mining_block_difficulty_miner
          })
        else
          miner_name = HumanHash.humanize(miner[:mid])
          debug "miner #{miner_name} found nonce at timestamp #{block.mined_timestamp }.. (nonces: #{miner[:context][:nonces].size}) mined with difficulty #{mined_difficulty} "

          miner[:context][:nonces].push(nonce)

          debug "found nonce of #{block.nonce} that doesn't satisfy block difficulty, checking if it is the best so far"
          current_miner_difficulty = block_difficulty_to_miner_difficulty(@blockchain.mining_block_difficulty)
          if (mined_difficulty > current_miner_difficulty) && (mined_difficulty > @highest_difficulty_mined_so_far)
            debug "This block is now the most difficult recorded"
            @most_difficult_block_so_far = block.dup
            @highest_difficulty_mined_so_far = mined_difficulty
          else
            debug "This block was not the most difficult recorded, miner still gets credit for sending the nonce"
          end
          if block.mined_timestamp > block.timestamp + (Consensus::POW_TARGET_SPACING * 0.90).to_i32
            if @highest_difficulty_mined_so_far > 0
              debug "Time has expired ... the block with the most difficult nonce recorded so far will be minted: #{@highest_difficulty_mined_so_far}"
              @most_difficult_block_so_far.to_s
              mint_block(@most_difficult_block_so_far)
            else
              debug "Time has expired ... but no nonce with a difficulty larger than miner difficulty (#{current_miner_difficulty}) has been received.. keep waiting"
            end
          end
        end
      end
    end

    def mint_block(block : Block)
      node.new_block(block)
      node.send_block(block)
      @highest_difficulty_mined_so_far = 0
      clear_nonces
    end

    def clear_nonces
      @miners.each do |m|
        m[:context][:nonces].clear
      end
    end

    def broadcast
      info "#{magenta("UPDATED BLOCK")}: #{light_green(@blockchain.mining_block.index)} at difficulty: #{light_cyan(@blockchain.mining_block_difficulty)}"
      debug "new block difficulty: #{@blockchain.mining_block_difficulty}, " +
            "mining difficulty: #{@blockchain.mining_block_difficulty_miner}"

      @miners.each do |miner|
        send(miner[:socket], M_TYPE_MINER_BLOCK_UPDATE, {
          block:      @blockchain.mining_block,
          difficulty: @blockchain.mining_block_difficulty_miner
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

    private def node
      @blockchain.node
    end

    include Protocol
    include Consensus
    include Common::Color
  end
end
