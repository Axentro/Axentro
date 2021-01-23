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

    def initialize(@difficulty, @deviance); end
  end

  class MinersManager < HandleSocket
    alias Miners = Array(Miner)
    getter miners : Miners = Miners.new

    @most_difficult_block_so_far : SlowBlock
    @block_start_time : Int64
    @nonce_meta_map : Hash(String, Array(NonceMeta)) = {} of String => Array(NonceMeta)

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

      miner = Miner.new(socket, mid, @blockchain.mining_block_difficulty_miner)

      @miners << miner

      @nonce_meta_map[miner.mid] = [NonceMeta.new(2, 0_i64)]

      remote_address = context.try(&.request.remote_address.to_s) || "unknown"
      miner_name = HumanHash.humanize(mid)
      info "new miner (#{remote_address}) : #{light_green(miner_name)} (#{@miners.size})"

      send(socket, M_TYPE_MINER_HANDSHAKE_ACCEPTED, {
        version:    Core::CORE_VERSION,
        block:      @blockchain.mining_block,
        difficulty: 2,
      })

      # spawn do
      #   loop do
      #     sleep 30
      #     puts "MINER CHECK"
      #     @miners.each do |miner|
      #       puts "In miner"
      #       existing_miner_nonces = MinerNoncePool.find_by_mid(miner.mid)
      #       if existing_miner_nonces.size > 0
      #         nonce_meta = @nonce_meta_map[miner.mid]
      #         last_difficulty = miner.difficulty
      #         deviance = __timestamp - existing_miner_nonces.last.timestamp

      #         if deviance > 10000
      #           last_difficulty = miner.difficulty
      #           miner.difficulty = Math.max(1, miner.difficulty - 1)
      #           if last_difficulty != miner.difficulty
      #             info "(check) decreased difficulty to #{miner.difficulty} for deviance: #{deviance}"
      #             send_updated_block(miner.socket, miner.difficulty)
      #           end
      #         else
      #           last_difficulty = miner.difficulty
      #           miner.difficulty = Math.max(1, miner.difficulty + 1)
      #           if last_difficulty != miner.difficulty
      #             info "(check) increased difficulty to #{miner.difficulty} for deviance: #{deviance}"
      #             send_updated_block(miner.socket, miner.difficulty)
      #           end
      #         end

      #         # add the nonce to the historic tracking
      #         @nonce_meta_map[miner.mid] << NonceMeta.new(miner.difficulty, deviance)
      #       else
      #         # no nonces found within 30 secs so decrease difficulty
      #         miner.difficulty = Math.max(1, miner.difficulty - 1)
      #         info "(check) decrease difficulty to #{miner.difficulty} as no nonces found within 30 seconds"
      #         send_updated_block(miner.socket, miner.difficulty)

      #         # add the nonce to the historic tracking
      #         @nonce_meta_map[miner.mid] << NonceMeta.new(miner.difficulty, 0_i64)
      #       end
      #     end
      #   end
      # end
    end

    def found_nonce(socket, _content)
      return unless node.phase == SetupPhase::DONE

      _m_content = MContentMinerFoundNonce.from_json(_content)

      mined_nonce = _m_content.nonce
      mined_timestamp = mined_nonce.timestamp
      mined_difficulty = mined_nonce.difficulty

      if miner = find?(socket)
        if nonce_meta = @nonce_meta_map[miner.mid]?
          block = @blockchain.mining_block.with_nonce(mined_nonce.value).with_timestamp(mined_timestamp).with_difficulty(mined_difficulty)
          block_hash = block.to_hash

          # puts block.to_json

          meta = nonce_meta.last

          # validate incoming nonce timestamp - should not be too far out from current time in utc
          if @blockchain.miner_nonce_pool.find(mined_nonce)
            message = "nonce #{mined_nonce.value} has already been discovered"
            warning message
            send_invalid_block_update(socket, meta.difficulty, message)
          end

          if mined_timestamp < @blockchain.mining_block.timestamp
            message = "received nonce was mined before current mining block was created, ignore"
            warning message
            send_invalid_block_update(socket, meta.difficulty, message)
          end

          mined_difficulty = valid_pow?(block_hash, mined_nonce.value, mined_difficulty)
          if mined_difficulty < meta.difficulty
            warning "difficulty for nonce: #{mined_nonce.value} was #{mined_difficulty} and expected #{meta.difficulty} for block hash: #{block_hash}"
            send_invalid_block_update(socket, meta.difficulty, "updated block because your nonce: #{mined_nonce.value} was invalid, actual difficulty: #{mined_difficulty} did not match expected: #{meta.difficulty}")
          else
            info "Nonce #{mined_nonce.value} at difficulty: #{mined_difficulty} was found"

            # add nonce to pool
            mined_nonce = mined_nonce.with_node_id(node.get_node_id).with_mid(miner.mid)
            @blockchain.add_miner_nonce(mined_nonce)

            # throttle nonce difficulty target

            # find last nonce the miner sent
            existing_miner_nonces = MinerNoncePool.find_by_mid(miner.mid)
            if existing_miner_nonces.size > 0
              last_miner_nonce = existing_miner_nonces.sort_by { |mn| mn.timestamp }.reverse
              time_difference = mined_timestamp - last_miner_nonce.first.timestamp

              nonce_meta = @nonce_meta_map[miner.mid]
              average_deviance = (nonce_meta.map(&.deviance).sum / nonce_meta.size).to_i
              average_difficulty = (nonce_meta.map(&.difficulty).sum / nonce_meta.size).to_i

              puts "DEVIANCE: #{average_deviance}"
              if average_deviance > 10000
                # if the last nonce the miner sent was more than 10 seconds ago since last nonce - decrease difficulty - resend block
                last_difficulty = miner.difficulty
                miner.difficulty = Math.max(1, average_difficulty - 1)
                if last_difficulty != miner.difficulty
                  error "(found_nonce) decrease difficulty to #{miner.difficulty} for deviance: #{average_deviance}"
                  send_adjust_block_difficulty(miner.socket, miner.difficulty, "dynamically decreasing difficulty from #{last_difficulty} to #{miner.difficulty}")
                end
              else
                puts "AVG DIFF: #{average_difficulty}"
                last_difficulty = miner.difficulty
                miner.difficulty = Math.max(1, average_difficulty + 2)
                if last_difficulty != miner.difficulty
                  error "(found_nonce) increased difficulty to #{miner.difficulty} for deviance: #{average_deviance}"
                  send_adjust_block_difficulty(miner.socket, miner.difficulty, "dynamically increasing difficulty from #{last_difficulty} to #{miner.difficulty}")
                end

                # if average_deviance < 1000
                #   # if the last nonce the miner sent was less than 10 seconds ago since last nonce - increase difficulty - resend block
                #   puts "AVG DIFF: #{average_difficulty}"
                #   last_difficulty = miner.difficulty
                #   miner.difficulty = Math.max(1, average_difficulty + 8)
                #   if last_difficulty != miner.difficulty
                #     error "(found_nonce) increased difficulty to #{miner.difficulty} for deviance: #{average_deviance}"
                #     send_adjust_block_difficulty(miner.socket, miner.difficulty)
                #   end
                # elsif average_deviance < 3000
                #   puts "AVG DIFF: #{average_difficulty}"
                #   last_difficulty = miner.difficulty
                #   miner.difficulty = Math.max(1, average_difficulty + 7)
                #   if last_difficulty != miner.difficulty
                #     error "(found_nonce) increased difficulty to #{miner.difficulty} for deviance: #{average_deviance}"
                #     send_adjust_block_difficulty(miner.socket, miner.difficulty)
                #   end
                # elsif average_deviance < 5000
                #   puts "AVG DIFF: #{average_difficulty}"
                #   last_difficulty = miner.difficulty
                #   miner.difficulty = Math.max(1, average_difficulty + 6)
                #   if last_difficulty != miner.difficulty
                #     error "(found_nonce) increased difficulty to #{miner.difficulty} for deviance: #{average_deviance}"
                #     send_adjust_block_difficulty(miner.socket, miner.difficulty)
                #   end
                # elsif average_deviance < 8000
                #   puts "AVG DIFF: #{average_difficulty}"
                #   last_difficulty = miner.difficulty
                #   miner.difficulty = Math.max(1, average_difficulty + 5)
                #   if last_difficulty != miner.difficulty
                #     error "(found_nonce) increased difficulty to #{miner.difficulty} for deviance: #{average_deviance}"
                #     send_adjust_block_difficulty(miner.socket, miner.difficulty)
                #   end
                # else
                #   puts "AVG DIFF: #{average_difficulty}"
                #   last_difficulty = miner.difficulty
                #   miner.difficulty = Math.max(1, average_difficulty + 4)
                #   if last_difficulty != miner.difficulty
                #     error "(found_nonce) increased difficulty to #{miner.difficulty} for deviance: #{average_deviance}"
                #     send_adjust_block_difficulty(miner.socket, miner.difficulty)
                #   end
                # end
              end

              # add the nonce to the historic tracking
              @nonce_meta_map[miner.mid] << NonceMeta.new(miner.difficulty, time_difference)
            end

            # track the highest nonce within 2 minutes and mint the block after 2 mins approx
            debug "found nonce of #{block.nonce} that doesn't satisfy block difficulty, checking if it is the best so far"
            current_miner_difficulty = block_difficulty_to_miner_difficulty(@blockchain.mining_block_difficulty)
            if (mined_difficulty > current_miner_difficulty) && (mined_difficulty > @highest_difficulty_mined_so_far)
              debug "This block is now the most difficult recorded"
              @most_difficult_block_so_far = block.dup
              @highest_difficulty_mined_so_far = mined_difficulty
            else
              debug "This block was not the most difficult recorded, miner still gets credit for sending the nonce"
            end
            if mined_timestamp > @block_start_time + (Consensus::POW_TARGET_SPACING * 0.90).to_i32
              if @highest_difficulty_mined_so_far > 0
                debug "Time has expired for block #{block.index} ... the block with the most difficult nonce recorded so far will be minted: #{@highest_difficulty_mined_so_far}"
                @most_difficult_block_so_far.to_s
                mint_block(@most_difficult_block_so_far)
              else
                # should decrease difficulty here if no block found within 2 mins
                debug "Time has expired for block #{block.index} ... but no nonce with a difficulty larger than miner difficulty (#{current_miner_difficulty}) has been received.. keep waiting"
              end
            end
          end
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
      return send(socket, M_TYPE_MINER_HANDSHAKE_REJECTED, {reason: reason})
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
