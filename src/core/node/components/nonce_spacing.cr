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
  MINER_BOUNDARY = 1_800_000  # 30 mins
  BLOCK_BOUNDARY =   120_000  # 2 mins
  MINER_WOBBLE   = 60_000 * 3 # 3 mins

  class NonceMeta
    property difficulty : Int32
    property last_found_time : Int64

    def initialize(@difficulty, @last_found_time); end
  end

  struct NonceSpacingResult
    property difficulty : Int32
    property reason : String

    def initialize(@difficulty, @reason); end
  end

  class NonceSpacing
    @nonce_meta_map : Hash(String, Array(NonceMeta)) = {} of String => Array(NonceMeta)

    def initialize
    end

    def get_meta_map(mid : String)
      @nonce_meta_map[mid]?
    end

    def leading_miner(miners : Array(Miner)) : Miner?
      grouped = miners.group_by(&.difficulty)
      return unless grouped.keys.size > 0
      grouped[grouped.keys.sort.last].first
    end

    def compute(miner : Miner, in_check : Bool = false) : NonceSpacingResult?
      # The miner should be tracked in nonce_meta to apply throttling
      if nonce_meta = @nonce_meta_map[miner.mid]?
        # did miner find any nonces yet?
        found_nonces = nonce_meta
        # info "did miner find nonces yet?"
        if found_nonces.size > 0
          # yes miner found nonces

          # if last nonce was found less than miner boundary mins increase difficulty
          last_nonce_found = found_nonces.last.last_found_time
          deviation = __timestamp - last_nonce_found
          if deviation < MINER_BOUNDARY + rand(MINER_WOBBLE)
            return if in_check # don't increase difficulty every time we check
            verbose "found nonce within boundary mins so increase difficulty"
            # if this occurs immediately after this miner finds a block deviation will be 0
            # but if found at another time then this will choose a difficulty
            difficulty_amount = calculate_difficulty_amount(deviation)
            increase_difficulty_by_last(miner, difficulty_amount, deviation)
          else
            # else decrease difficulty
            verbose "found nonce later than boundary mins so decrease difficulty"
            decrease_difficulty_by_last(miner)
          end
        else
          warning "miner (#{miner.ip}:#{miner.port}) (#{miner.mid}) (#{miner.name}) did not find nonces yet so not adjusting the difficulty"
        end
      else
        warning "miner (#{miner.ip}:#{miner.port}) (#{miner.mid}) (#{miner.name}) was not found in the nonce meta map so not adjusting difficulty"
      end
    end

    def calculate_difficulty_amount(deviation) : Int32
      debug "deviation was: #{deviation}"
      case deviation
      when .< 60_000
        8
      when .< 180_000
        6
      else
        4
      end
    end

    def decrease_difficulty_by_last(miner)
      last_difficulty = miner.difficulty
      miner.difficulty = Math.max(1, last_difficulty - 1)
      if last_difficulty != miner.difficulty
        info "(#{miner.mid}) (last nonce) decrease difficulty from #{last_difficulty} to #{miner.difficulty}"
        return NonceSpacingResult.new(miner.difficulty, "dynamically decreasing difficulty from #{last_difficulty} to #{miner.difficulty}")
      end
    end

    def increase_difficulty_by_last(miner, difficulty_amount, last_deviance)
      last_difficulty = miner.difficulty
      miner.difficulty = Math.max(1, last_difficulty + difficulty_amount)
      if last_difficulty != miner.difficulty
        info "(#{miner.mid}) (last nonce) increasing difficulty from #{last_difficulty} to #{miner.difficulty} for last deviance: #{last_deviance}"
        return NonceSpacingResult.new(miner.difficulty, "dynamically increasing difficulty from #{last_difficulty} to #{miner.difficulty}")
      end
    end

    def track_miner_difficulty(mid : String, difficulty : Int32)
      @nonce_meta_map[mid] ||= [] of NonceMeta
      @nonce_meta_map[mid] << NonceMeta.new(difficulty, __timestamp)
    end

    include Logger
    include Metrics
  end
end
