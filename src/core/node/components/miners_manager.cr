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
require "./metrics"

module ::Axentro::Core::NodeComponents
  class Miner
    property socket : HTTP::WebSocket
    property mid : String
    property difficulty : Int32
    property ip : String
    property port : Int32
    property name : String
    property address : String

    def initialize(@socket, @mid, @difficulty, @ip, @port, @name, @address); end
  end

  struct MinerMortality
    property ip : String
    property action : String
    property timestamp : Int64

    def initialize(@ip, @action, @timestamp); end
  end

  struct MinerConnected
    property mid : String
    property at : Int64

    def initialize(@mid, @at); end
  end

  class MinersManager < HandleSocket
    alias Miners = Array(Miner)
    getter miners : Miners = Miners.new

    @most_difficult_block_so_far : Block
    @block_start_time : Int64
    @nonce_spacing : NonceSpacing = NonceSpacing.new
    @last_ensured : Int64
    @leading_miner : Miner?
    @miner_connected : Array(MinerConnected) = [] of MinerConnected

    getter miner_mortality : Array(MinerMortality) = [] of MinerMortality

    def initialize(@blockchain : Blockchain, @is_private_node : Bool)
      @highest_difficulty_mined_so_far = 0
      @block_start_time = __timestamp
      @most_difficult_block_so_far = @blockchain.genesis_block
      @last_ensured = @block_start_time
    end

    def self.ban_list(miner_mortality : Array(MinerMortality))
      _deviance = 10_000
      _ban_duration = 600_000 # 10 mins
      _ban_tolerance = 10
      now = __timestamp

      bans = Set(String).new

      miner_mortality.group_by(&.ip).each do |ip, history|
        time_history = history.map(&.timestamp)
        result = time_history.last(10).in_groups_of(2, 0_i64).map { |group|
          (group.first.not_nil! - group.last.not_nil!).abs
        }.count { |deviance| deviance < _deviance }

        last_action = time_history.max
        miner_mortality.reject! { |m| m.ip == ip } if (now - last_action > _ban_duration)

        bans << ip if result >= 5
      end

      bans
    end

    private def node
      @blockchain.node
    end

    def ensure_block_mined
      if @miners.size > 0
        # if no nonces found within 1 minute 30 secs of block start then reduce difficulty to ensure block is mined
        nonces_for_block = MinerNoncePool.embedded
        no_nonces = nonces_for_block.size == 0
        now = __timestamp
        deviation = now - @block_start_time
        boundary = 90_000 # 1 min 30 secs
        last_ensured_deviation = now - @last_ensured
        verbose "checking ensure: #{deviation > boundary}, no nonces: #{no_nonces}, last: #{last_ensured_deviation > 10_000}"
        if deviation > boundary && no_nonces && last_ensured_deviation > 10_000
          warning "no nonces found for block within 1 min 30 secs - attempting to ensure 2 min block time"

          @miners.each do |miner|
            if connected_mid = @miner_connected.find { |mc| mc.mid == miner.mid }
              connected_duration = __timestamp - connected_mid.at
              if connected_duration >= 120_000
                METRICS_MINERS_COUNTER[kind: "decrease_difficulty_ensure_block"].inc
                current_difficulty = miner.difficulty
                miner.difficulty = current_difficulty - 1
                send_adjust_block_difficulty(miner.socket, miner.difficulty, "reducing difficulty from #{current_difficulty} to #{miner.difficulty} to ensure block time")
                @last_ensured = __timestamp
              end
            end
          end
        end
      end
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
      if version_check.invalid?
        METRICS_MINERS_COUNTER[kind: "old_miner"].inc
        reject_miner_connection(socket, version_check.reason)
      end

      max_miners_check = MinerValidation.can_add_miners?(miners.size, @blockchain.max_miners)
      reject_miner_connection(socket, max_miners_check.reason) if max_miners_check.invalid?

      public_node_check = MinerValidation.is_public_node?(@is_private_node)
      reject_miner_connection(socket, public_node_check.reason) if public_node_check.invalid?

      remote_connection = context.try { |c| NetworkUtil.get_remote_connection(c.request) }
      remote_ip = remote_connection.try(&.ip) || "unknown"
      remote_port = remote_connection.try(&.port) || 0
      miner_name = HumanHash.humanize(mid)

      miner = Miner.new(socket, mid, @blockchain.mining_block.difficulty, remote_ip, remote_port, miner_name, address)

      @miners << miner
      now = __timestamp
      @miner_mortality << MinerMortality.new(miner.ip, "joined", now)
      @miner_connected << MinerConnected.new(miner.mid, now)

      METRICS_MINERS_COUNTER[kind: "joined"].inc
      METRICS_CONNECTED_GAUGE[kind: "miners"].set @miners.size

      @nonce_spacing.track_miner_difficulty(miner.mid, @blockchain.mining_block.difficulty)

      info "joined miner (#{miner.ip}:#{miner.port}) : #{miner.address} #{light_green(miner.name)} (#{miner.mid}) (#{@miners.size})"

      send(socket, M_TYPE_MINER_HANDSHAKE_ACCEPTED, {
        version:    Core::CORE_VERSION,
        block:      @blockchain.mining_block,
        difficulty: @blockchain.mining_block.difficulty,
      })

      spawn do
        loop do
          sleep rand(10..20)
          verbose "in check loop"
          # if miner was removed break out of loop
          break unless @miners.map(&.mid).includes?(miner.mid)
          if spacing = @nonce_spacing.compute(miner, true)
            verbose "check was computed for #{miner.mid}"
            send_adjust_block_difficulty(miner.socket, spacing.difficulty, spacing.reason)
          end
          check_if_block_has_expired
        end
      end
    rescue
      # short term message until all miners have upgraded to sem ver approach
      reason = "your miner is out of date, please update it (node version: #{Core::CORE_VERSION})"
      reject_miner_connection(socket, reason)
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def found_nonce(socket, _content)
      return unless node.phase == SetupPhase::DONE

      _m_content = MContentMinerFoundNonce.from_json(_content)

      mined_nonce = _m_content.nonce
      mined_timestamp = mined_nonce.timestamp
      mined_difficulty = mined_nonce.difficulty

      if miner = find?(socket)
        if connected_mid = @miner_connected.find { |mc| mc.mid == miner.mid }
          connected_duration = __timestamp - connected_mid.at
          if connected_duration < 120_000 && @miners.size > 1
            message = "(#{miner.mid}) rejecting nonce as miner was only connected for #{connected_duration / 1000} secs but mininum is 120 secs for reward"
            warning message
            # we still want to increase the difficulty here to regulate mining for miner loyalty strategy
            # found a nonce so track it in the history
            @nonce_spacing.track_miner_difficulty(miner.mid, miner.difficulty)

            # throttle nonce difficulty target
            if spacing = @nonce_spacing.compute(miner)
              send_adjust_block_difficulty(miner.socket, spacing.difficulty, spacing.reason)
            end

            return send_insufficient_duration(socket, message, connected_duration)
          end

          block = @blockchain.mining_block.with_nonce(mined_nonce.value).with_difficulty(mined_difficulty)
          block_hash = block.to_hash

          if @blockchain.miner_nonce_pool.find(mined_nonce)
            message = "nonce #{mined_nonce.value} has already been discovered"
            warning message
            return send_invalid_block_update(socket, mined_difficulty, message)
          end

          # allow a bit of extra time for latency for nonces
          mining_block_with_buffer = @blockchain.mining_block.timestamp - 10_000
          if mined_timestamp < mining_block_with_buffer
            message = "invalid timestamp for received nonce: #{mined_nonce.value} nonce mined at: #{Time.unix_ms(mined_timestamp)} before current mining block was created at: #{Time.unix_ms(mining_block_with_buffer)} (#{Time.unix_ms(@blockchain.mining_block.timestamp)})"
            warning message
            return send_invalid_block_update(socket, mined_difficulty, message)
          end

          actual_difficulty = calculate_pow_difficulty(block.mining_version, block_hash, mined_nonce.value, mined_difficulty)
          info "(#{miner.mid}) (#{miner.ip}) (#{miner.address}) incoming nonce: #{mined_nonce.value} (actual: #{actual_difficulty}, expected: #{mined_difficulty})"
          if actual_difficulty < mined_difficulty
            METRICS_NONCES_COUNTER[kind: "invalid"].inc
            warning "difficulty for nonce: #{mined_nonce.value} was #{actual_difficulty} and expected #{mined_difficulty} for block hash: #{block_hash}"
            send_invalid_block_update(socket, mined_difficulty, "updated block because your nonce: #{mined_nonce.value} was invalid, actual difficulty: #{actual_difficulty} did not match expected: #{mined_difficulty}")
          else
            METRICS_NONCES_COUNTER[kind: "valid"].inc
            debug "Nonce #{mined_nonce.value} at difficulty: #{actual_difficulty} was found"

            # add nonce to pool
            mined_nonce = mined_nonce.with_node_id(node.get_node_id).with_mid(miner.mid)
            @blockchain.add_miner_nonce(mined_nonce, false)
            node.send_miner_nonce(mined_nonce)

            # found a nonce so track it in the history
            @nonce_spacing.track_miner_difficulty(miner.mid, miner.difficulty)

            # throttle nonce difficulty target
            if spacing = @nonce_spacing.compute(miner)
              send_adjust_block_difficulty(miner.socket, spacing.difficulty, spacing.reason)
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
      time_boundary = BLOCK_BOUNDARY + rand(20000)
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

    def send_warning(socket, reason : String, remaining_duration : Int32)
      send(socket, M_TYPE_MINER_EXCEED_RATE, {
        reason:             reason,
        remaining_duration: remaining_duration,
      })
    end

    def send_insufficient_duration(socket, reason : String, connected_duration : Int64)
      send(socket, M_TYPE_MINER_INSUFFICIENT_DURATION, {
        reason:             reason,
        connected_duration: connected_duration,
      })
    end

    def find?(socket : HTTP::WebSocket) : Miner?
      @miners.find { |m| m.socket == socket }
    end

    def reject_miner_connection(socket : HTTP::WebSocket, reason : String)
      sleep 10 + rand(5)
      send(socket, M_TYPE_MINER_HANDSHAKE_REJECTED, {reason: reason})
    end

    def mint_block(block : Block)
      METRICS_BLOCKS_COUNTER[kind: "slow"].inc
      @leading_miner = nil
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
        send_updated_block(miner.socket, miner.difficulty)
      end
    end

    def clean_connection(socket)
      current_size = @miners.size
      message = ""
      if mnr = @miners.find { |miner| miner.socket == socket }
        message = "(#{mnr.ip}:#{mnr.port}) : #{mnr.address} #{light_green(mnr.name)} (#{mnr.mid})"
        @miner_mortality << MinerMortality.new(mnr.ip, "remove", __timestamp)
        mnr.socket.close
        @miners.reject! { |m| m.mid == mnr.mid }
        @miner_connected.reject! { |mc| mc.mid == mnr.mid }
        @nonce_spacing.delete(mnr.mid)
        METRICS_MINERS_COUNTER[kind: "removed"].inc
      end
      # @miners.reject! do |miner|
      #   r = miner.socket == socket
      #   METRICS_MINERS_COUNTER[kind: "removed"].inc if r
      #   r
      # end

      METRICS_CONNECTED_GAUGE[kind: "miners"].set @miners.size
      info "remove miner #{message} (#{current_size} -> #{@miners.size})" if current_size > @miners.size
    end

    include Protocol
    include Consensus
    include NonceModels
    include Common::Color
    include Metrics
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
      MinerValidationResult.new(SemVer.new(Core::CORE_VERSION).major_version > SemVer.new(version).major_version,
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
