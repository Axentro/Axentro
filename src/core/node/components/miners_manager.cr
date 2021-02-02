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

  class MinersManager < HandleSocket
    alias Miners = Array(Miner)
    getter miners : Miners = Miners.new

    @most_difficult_block_so_far : SlowBlock
    @block_start_time : Int64
    @nonce_spacing : NonceSpacing = NonceSpacing.new

    def initialize(@blockchain : Blockchain, @is_private_node : Bool)
      @highest_difficulty_mined_so_far = 0
      @block_start_time = __timestamp
      @most_difficult_block_so_far = @blockchain.genesis_block
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

      miner = Miner.new(socket, mid, @blockchain.mining_block.difficulty)

      @miners << miner

      existing_miner_nonces = MinerNoncePool.find_by_mid(miner.mid)
      @nonce_spacing.add_nonce_meta(miner.mid, @blockchain.mining_block.difficulty, existing_miner_nonces)

      remote_address = context.try(&.request.remote_address.to_s) || "unknown"
      miner_name = HumanHash.humanize(mid)
      info "new miner (#{remote_address}) : #{light_green(miner_name)} (#{@miners.size})"

      send(socket, M_TYPE_MINER_HANDSHAKE_ACCEPTED, {
        version:    Core::CORE_VERSION,
        block:      @blockchain.mining_block,
        difficulty: @blockchain.mining_block.difficulty,
      })

      spawn do
        loop do
          sleep 10
          verbose "in check loop"
          existing_miner_nonces = MinerNoncePool.find_by_mid(miner.mid)
          if spacing = @nonce_spacing.compute(@block_start_time, miner, existing_miner_nonces, true)
            info "check was computed for #{miner.mid}"
            send_adjust_block_difficulty(miner.socket, spacing.difficulty, spacing.reason)
            @nonce_spacing.add_nonce_meta(miner.mid, spacing.difficulty, existing_miner_nonces)
          end
          check_if_block_has_expired
        end
      end
    end

    def found_nonce(socket, _content)
      return unless node.phase == SetupPhase::DONE

      _m_content = MContentMinerFoundNonce.from_json(_content)

      mined_nonce = _m_content.nonce
      mined_timestamp = mined_nonce.timestamp
      mined_difficulty = mined_nonce.difficulty

      if miner = find?(socket)
        if nonce_meta = @nonce_spacing.get_meta_map(miner.mid)
          block = @blockchain.mining_block.with_nonce(mined_nonce.value).with_difficulty(mined_difficulty)
          block_hash = block.to_hash

          meta = nonce_meta.last

          if @blockchain.miner_nonce_pool.find(mined_nonce)
            message = "nonce #{mined_nonce.value} has already been discovered"
            warning message
            send_invalid_block_update(socket, meta.difficulty, message)
          end

          if mined_timestamp < @blockchain.mining_block.timestamp
            message = "invalid timestamp for received nonce: #{mined_nonce.value} nonce mined at: #{Time.unix_ms(mined_timestamp)} before current mining block was created at: #{Time.unix_ms(@blockchain.mining_block.timestamp)}"
            warning message
            send_invalid_block_update(socket, meta.difficulty, message)
          end

          mined_difficulty = calculate_pow_difficulty(block_hash, mined_nonce.value, mined_difficulty)
          if mined_difficulty < meta.difficulty
            warning "difficulty for nonce: #{mined_nonce.value} was #{mined_difficulty} and expected #{meta.difficulty} for block hash: #{block_hash}"
            send_invalid_block_update(socket, meta.difficulty, "updated block because your nonce: #{mined_nonce.value} was invalid, actual difficulty: #{mined_difficulty} did not match expected: #{meta.difficulty}")
          else
            debug "Nonce #{mined_nonce.value} at difficulty: #{mined_difficulty} was found"

            # add nonce to pool
            mined_nonce = mined_nonce.with_node_id(node.get_node_id).with_mid(miner.mid)
            @blockchain.add_miner_nonce(mined_nonce)
            node.send_miner_nonce(mined_nonce)

            # throttle nonce difficulty target
            existing_miner_nonces = MinerNoncePool.find_by_mid(miner.mid)
            if existing_miner_nonces.size > 0
              if spacing = @nonce_spacing.compute(@block_start_time, miner, existing_miner_nonces)
                send_adjust_block_difficulty(miner.socket, spacing.difficulty, spacing.reason)
              end

              # add the nonce to the historic tracking
              @nonce_spacing.add_nonce_meta(miner.mid, miner.difficulty, existing_miner_nonces)
            end

            # make block the most difficult recorded if it's difficulty exceeds the current most difficult
            if mined_difficulty > @highest_difficulty_mined_so_far
              debug "This block is now the most difficult recorded"
              @most_difficult_block_so_far = block.dup
              @highest_difficulty_mined_so_far = mined_difficulty
            end

            check_if_block_has_expired
          end
        end
      end
    end

    def check_if_block_has_expired
      # allow some random time to reduce the chance of blocks minted with identical timestamps on different nodes
      time_boundary = (Consensus::POW_TARGET_SPACING * 0.90).to_i32 + rand(20000)
      start_with_boundary = @block_start_time + time_boundary
      duration = __timestamp - @block_start_time
      debug "has expired? started: #{Time.unix_ms(@block_start_time)} ending: #{Time.unix_ms(start_with_boundary)}, duration: #{duration / 1000}"
      if __timestamp > start_with_boundary
        if @highest_difficulty_mined_so_far > 0
          debug "minting the highest difficulty block so far"
          mint_block(@most_difficult_block_so_far)
        end
      end
    end

    def send_adjust_block_difficulty(socket, difficulty : Int32, reason : String)
      send(socket, M_TYPE_MINER_BLOCK_DIFFICULTY_ADJUST, {
        block:      @blockchain.mining_block,
        difficulty: difficulty,
        reason:     reason,
      })
    end

    def send_invalid_block_update(socket, difficulty : Int32, reason : String)
      send(socket, M_TYPE_MINER_BLOCK_INVALID, {
        block:      @blockchain.mining_block,
        difficulty: difficulty,
        reason:     reason,
      })
    end

    def send_updated_block(socket, difficulty : Int32)
      send(socket, M_TYPE_MINER_BLOCK_UPDATE, {
        block:      @blockchain.mining_block,
        difficulty: difficulty,
      })
    end

    def find?(socket : HTTP::WebSocket) : Miner?
      @miners.find { |m| m.socket == socket }
    end

    def reject_miner_connection(socket : HTTP::WebSocket, reason : String)
      send(socket, M_TYPE_MINER_HANDSHAKE_REJECTED, {reason: reason})
    end

    def mint_block(block : SlowBlock)
      @highest_difficulty_mined_so_far = 0
      @block_start_time = __timestamp
      node.new_block(block)
      node.send_block(block)
    end

    def forget_most_difficult
      debug "Forgetting most difficult"
      @highest_difficulty_mined_so_far = 0
      @block_start_time = __timestamp
    end

    def broadcast
      info "#{magenta("PREPARING NEXT SLOW BLOCK")}: #{light_green(@blockchain.mining_block.index)} at difficulty: #{light_cyan(@blockchain.mining_block.difficulty)}"

      @miners.each do |miner|
        send(miner.socket, M_TYPE_MINER_BLOCK_UPDATE, {
          block:      @blockchain.mining_block,
          difficulty: @blockchain.mining_block.difficulty,
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
