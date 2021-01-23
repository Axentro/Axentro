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

    def compute(miner : Miner, check : Bool = false) : NonceSpacingResult?
      prefix = check ? "(check)" : "(nonce)"
      if nonce_meta = @nonce_meta_map[miner.mid]?
        moving_average = nonce_meta.size < 10 ? nonce_meta : nonce_meta.last(10)
        average_deviance = (moving_average.map(&.deviance).sum / moving_average.size).to_i
        average_difficulty = (moving_average.map(&.difficulty).sum / moving_average.size).to_i

        if average_deviance > 10000
          debug "average difficulty: #{average_difficulty}, average deviance: #{average_deviance}"
          last_difficulty = miner.difficulty
          miner.difficulty = Math.max(1, average_difficulty - 1)
          if last_difficulty != miner.difficulty
            debug "#{prefix} decrease difficulty to #{miner.difficulty} for deviance: #{average_deviance}"
            NonceSpacingResult.new(miner.difficulty, "dynamically decreasing difficulty from #{last_difficulty} to #{miner.difficulty}")
          end
        else
          last_difficulty = miner.difficulty
          miner.difficulty = Math.max(1, average_difficulty + 2)
          if last_difficulty != miner.difficulty
            debug "#{prefix} increased difficulty to #{miner.difficulty} for deviance: #{average_deviance}"
            NonceSpacingResult.new(miner.difficulty, "dynamically increasing difficulty from #{last_difficulty} to #{miner.difficulty}")
          end
        end
      else
        debug "#{prefix} no nonces found yet so decrease difficulty to #{miner.difficulty}"
        last_difficulty = miner.difficulty
        miner.difficulty -= 1
        NonceSpacingResult.new(miner.difficulty, "dynamically decreasing difficulty from #{last_difficulty} to #{miner.difficulty}")
      end
    end

    def add_nonce_meta(mid : String, difficulty : Int32, existing_nonces : Array(MinerNonce), mined_timestamp : Int64, check : Bool = false)
      if existing_nonces.size > 0
        last_miner_nonce = existing_nonces.sort_by { |mn| mn.timestamp }.reverse
        time_difference = mined_timestamp - last_miner_nonce.first.timestamp
      else
        prefix = check ? "(check)" : "(nonce)"
        debug "#{prefix} no nonces yet and difficulty is #{difficulty}"
        time_difference = 10001_i64
      end
      @nonce_meta_map[mid] ||= [] of NonceMeta
      @nonce_meta_map[mid] << NonceMeta.new(difficulty, time_difference, __timestamp)
    end

    include Logger
  end
end
