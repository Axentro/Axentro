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
  DEVIANCE_BOUNDARY_1 =     8000
  DEVIANCE_BOUNDARY_2 =    12000
  NO_NONCE_BOUNDARY   =    10000
  NO_NONCE_DEVIANCE   = 8001_i64
  MOVING_AVERAGE_SIZE =       20

  class NonceMeta
    property difficulty : Int32
    property deviance : Int64
    property last_change : Int64

    def initialize(@difficulty, @deviance, @last_change); end
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

    # build an average first - the first 20 nonces can go up and down
    # after 20 nonces - take the last 20 to calculate averages
    # ameba:disable Metrics/CyclomaticComplexity
    def compute(block_start_time : Int64, miner : Miner, existing_nonces : Array(MinerNonce), check : Bool = false) : NonceSpacingResult?
      prefix = check ? "(check)" : "(nonce)"
      # The miner should be tracked in nonce_meta to apply throttling
      if nonce_meta = @nonce_meta_map[miner.mid]?
        # Are there any existing nonces yet?
        if existing_nonces.size > 0
          # should we use averages or last nonce strategy?
          if nonce_meta.size > MOVING_AVERAGE_SIZE
            # use averages from last 20
            # if avg deviance > 10 secs - increase/decrease - do nothing boundary between 8-12 secs
            moving_average = nonce_meta.size < MOVING_AVERAGE_SIZE ? nonce_meta : nonce_meta.last(MOVING_AVERAGE_SIZE)
            average_deviance = (moving_average.map(&.deviance).sum.to_i / moving_average.size).to_i
            average_difficulty = (moving_average.map(&.difficulty).sum.to_i / moving_average.size).to_i

            if average_deviance < DEVIANCE_BOUNDARY_1
              increase_difficulty_by_average(miner, average_difficulty, average_deviance, prefix)
            elsif average_deviance < DEVIANCE_BOUNDARY_2
              # do nothing
            else
              decrease_difficulty_by_average(miner, average_difficulty, average_deviance, prefix)
            end
          else
            # use last nonce strategy
            # how long ago was the last nonce found?
            # less than 8 seconds? increase difficulty
            # between 8 -> 12 seconds? do nothing
            # more than 12 seconds? decrease difficulty
            last_nonce_found = nonce_meta.last.last_change
            if nonce_meta.size >= 2
              deviation = last_nonce_found - nonce_meta.last(2).first.last_change
            else
              deviation = __timestamp - last_nonce_found
            end

            if deviation < DEVIANCE_BOUNDARY_1
              increase_difficulty_by_last(miner, deviation, prefix)
            elsif deviation < DEVIANCE_BOUNDARY_2
              # do nothing
            else
              decrease_difficulty_by_last(miner, deviation, prefix)
            end
          end
        else
          # If no nonces found yet - ignoring nonce_meta.size
          # decrease difficulty if more than 10 seconds since block start
          deviation = __timestamp - block_start_time
          if deviation > NO_NONCE_BOUNDARY
            decrease_difficulty_by_last(miner, deviation, prefix)
          end
        end
      end
    end

    def decrease_difficulty_by_last(miner, last_deviance, prefix)
      last_difficulty = miner.difficulty
      miner.difficulty = Math.max(1, last_difficulty - 1)
      if last_difficulty != miner.difficulty
        info "(#{miner.mid}) #{prefix} (last nonce) decrease difficulty to #{miner.difficulty} for last deviance: #{last_deviance}"
        return NonceSpacingResult.new(miner.difficulty, "dynamically decreasing difficulty from #{last_difficulty} to #{miner.difficulty}")
      end
    end

    def decrease_difficulty_by_average(miner, average_difficulty, average_deviance, prefix)
      last_difficulty = miner.difficulty
      miner.difficulty = Math.max(1, average_difficulty - 1)
      if last_difficulty != miner.difficulty
        info "(#{miner.mid}) #{prefix} (average) decrease difficulty to #{miner.difficulty} for average deviance: #{average_deviance}"
        return NonceSpacingResult.new(miner.difficulty, "dynamically decreasing difficulty from #{last_difficulty} to #{miner.difficulty}")
      end
    end

    def increase_difficulty_by_last(miner, last_deviance, prefix)
      last_difficulty = miner.difficulty
      miner.difficulty = Math.max(1, last_difficulty + 1)
      if last_difficulty != miner.difficulty
        action = (last_difficulty > miner.difficulty) ? "decreasing" : "increasing"
        info "(#{miner.mid}) #{prefix} (last nonce) #{action} difficulty to #{miner.difficulty} for last deviance: #{last_deviance}"
        return NonceSpacingResult.new(miner.difficulty, "dynamically #{action} difficulty from #{last_difficulty} to #{miner.difficulty}")
      end
    end

    def increase_difficulty_by_average(miner, average_difficulty, average_deviance, prefix)
      last_difficulty = miner.difficulty
      miner.difficulty = Math.max(1, average_difficulty + 1)
      if last_difficulty != miner.difficulty
        action = (last_difficulty > miner.difficulty) ? "decreasing" : "increasing"
        info "(#{miner.mid}) #{prefix} (average) #{action} difficulty to #{miner.difficulty} for average deviance: #{average_deviance}"
        return NonceSpacingResult.new(miner.difficulty, "dynamically #{action} difficulty from #{last_difficulty} to #{miner.difficulty}")
      end
    end

    def add_nonce_meta(mid : String, difficulty : Int32, existing_nonces : Array(MinerNonce), check : Bool = false)
      now = __timestamp
      if nonce_meta = @nonce_meta_map[mid]?
        if existing_nonces.size > 0
          last_nonce_found = nonce_meta.last.last_change
          deviance = now - last_nonce_found
          @nonce_meta_map[mid] << NonceMeta.new(difficulty, deviance, now)
        else
          # no nonces yet so same as not tracked condition
          deviance = NO_NONCE_DEVIANCE
          @nonce_meta_map[mid] << NonceMeta.new(difficulty, deviance, now)
        end
      else
        # not tracked miner yet - so set deviance greater than cut off so it will decrease from the start
        deviance = NO_NONCE_DEVIANCE
        @nonce_meta_map[mid] ||= [] of NonceMeta
        @nonce_meta_map[mid] << NonceMeta.new(difficulty, deviance, now)
      end
    end

    include Logger
  end
end
