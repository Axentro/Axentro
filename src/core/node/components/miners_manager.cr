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

module ::Axentro::Core::NodeComponents
  class Miner
    property socket : HTTP::WebSocket
    property mid : String
    property difficulty : Int32

    def initialize(@socket, @mid, @difficulty); end
  end

  class NonceMeta
    property difficulty : Int32
    property deviance : Int64
    property block_hash : String

    def initialize(@difficulty, @deviance, @block_hash); end
  end

  class MinersManager < HandleSocket
    alias Miners = Array(Miner)
    getter miners : Miners = Miners.new

    @nonce_meta_map : Hash(String, Array(NonceMeta)) = {} of String => Array(NonceMeta)

    def initialize(@blockchain : Blockchain, @is_private_node : Bool) 
    end

    private def node
      @blockchain.node
    end

    def handshake(socket, context, _content)
      return unless node.phase == SetupPhase::DONE

      verbose "requested handshake from a miner"

      _m_content = MContentMinerHandshake.from_json(_content)

      version = _m_content.version
      address = _m_content.address
      mid = _m_content.mid

      network_check = MinerValidation.has_correct_network?(address, node.network_type)
      reject_miner_connection(socket, network_check.reason) if network_check.invalid?

      version_check = MinerValidation.has_valid_version?(version)
      reject_miner_connection(socket, version_check.reason) if version_check.invalid?

      max_miners_check = MinerValidation.can_add_miners?(miners.size, @blockchain.max_miners)
      reject_miner_connection(socket, max_miners_check.reason) if max_miners_check.invalid?

      public_node_check = MinerValidation.is_public_node?(@is_private_node)
      reject_miner_connection(socket, public_node_check.reason) if public_node_check.invalid?

      miner = Miner.new(socket, mid, @blockchain.mining_block_difficulty_miner)

      @miners << miner

      block_hash = @blockchain.mining_block.with_difficulty(Consensus::MINER_DIFFICULTY_TARGET).to_hash
      @nonce_meta_map[miner.mid] = [NonceMeta.new(Consensus::MINER_DIFFICULTY_TARGET, 0_i64, block_hash)]

      remote_address = context.try(&.request.remote_address.to_s) || "unknown"
      miner_name = HumanHash.humanize(mid)
      info "new miner (#{remote_address}) : #{light_green(miner_name)} (#{@miners.size})"

      send(socket, M_TYPE_MINER_HANDSHAKE_ACCEPTED, {
        version:     Core::CORE_VERSION,
        block_index: @blockchain.mining_block.index,
        block_hash:  block_hash,
        difficulty:  Consensus::MINER_DIFFICULTY_TARGET,
      })
    end

    def found_nonce(socket, _content)
      return unless node.phase == SetupPhase::DONE

      _m_content = MContentMinerFoundNonce.from_json(_content)

      miner_nonce = _m_content.nonce
      mined_timestamp = miner_nonce.timestamp
      miner_difficulty = miner_nonce.difficulty
      block_hash = miner_nonce.block_hash

      if miner = find?(socket)
        if nonce_meta = @nonce_meta_map[miner.mid]?
         
          meta_for_hash = nonce_meta.select{|nm| nm.block_hash == block_hash }
          if meta_for_hash.size > 0
            meta = meta_for_hash.last
 
            # validate incoming nonce timestamp - should not be too far out from current time in utc
                      
            mined_difficulty = valid_pow?(block_hash, miner_nonce.value, miner_difficulty)
            if mined_difficulty < meta.difficulty
              error "difficulty for nonce: #{miner_nonce.value} was #{mined_difficulty} and expected #{meta.difficulty} for block hash: #{block_hash}"
            else  
              info "Nonce #{miner_nonce.value} at difficulty: #{miner_difficulty} was found for block hash: #{block_hash}"

              # throttle nonce difficulty target
              
              # track the highest nonce within 2 minutes and mint the block after 2 mins approx

            end
          else
            # hash not tracked in meta so nonce is invalid
          end
        
        end
      end
    end

    def find?(socket : HTTP::WebSocket) : Miner?
      @miners.find { |m| m.socket == socket }
    end

    def reject_miner_connection(socket : HTTP::WebSocket, reason : String)
      return send(socket, M_TYPE_MINER_HANDSHAKE_REJECTED, {reason: reason})
    end

    def broadcast
      info "#{magenta("PREPARING NEXT SLOW BLOCK")}: #{light_green(@blockchain.mining_block.index)} at difficulty: #{light_cyan(@blockchain.mining_block_difficulty)}"
      debug "new block difficulty: #{@blockchain.mining_block_difficulty}, " +
            "mining difficulty: #{@blockchain.mining_block_difficulty_miner}"

      @miners.each do |miner|
        send(miner.socket, M_TYPE_MINER_BLOCK_UPDATE, {
          block:      @blockchain.mining_block,
          difficulty: @blockchain.mining_block_difficulty_miner,
        })
      end
    end

    def clean_connection(socket)
      current_size = @miners.size
      @miners.reject! { |miner| miner.socket == socket }

      info "a miner has been removed. (#{current_size} -> #{@miners.size})" if current_size > @miners.size
    end

    include Protocol
    include Consensus
    include NonceModels
    include Common::Color
  end

  struct MinerValidationResult
    property result : Bool
    property reason : String

    def initialize(@result, @reason); end

    def invalid?
      @result
    end
  end

  module MinerValidation
    extend self

    def has_correct_network?(address : String, node_network : String) : MinerValidationResult
      miner_network = Wallet.address_network_type(address)[:name]
      MinerValidationResult.new(miner_network != node_network, "Your miner address is set to #{miner_network} but this node is running as #{node_network}")
    end

    def has_valid_version?(version) : MinerValidationResult
      MinerValidationResult.new(Core::CORE_VERSION > version,
        "your miner is out of date, please update it (node version: #{Core::CORE_VERSION}, miner version: #{version})")
    end

    def can_add_miners?(miners_count : Int32, max_miners : Int32) : MinerValidationResult
      MinerValidationResult.new(miners_count >= max_miners,
        "The max number of miners allowed to connect to this node has been reached (#{max_miners})")
    end

    def is_public_node?(is_private : Bool) : MinerValidationResult
      MinerValidationResult.new(is_private, "Mining against private nodes is not supported")
    end
  end
end
