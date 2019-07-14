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

module ::Sushi::Core::Consensus

  def valid_pow?(block_hash : String, nonce : UInt64, difficulty : Int32) : Int32
    nonce_salt = nonce.to_s(16)
    nonce_salt = "0" + nonce_salt if nonce_salt.bytesize % 2 != 0

    nonce_slice = Slice(UInt8).new(nonce_salt.bytesize / 2)
    nonce_slice.size.times do |i|
      nonce_slice[i] = nonce_salt[i*2..i*2 + 1].to_u8(16)
    end

    buffer = Argon2::Engine.raw_hash_buffer(
      Argon2::Engine::EngineType::ARGON2ID, block_hash, nonce_slice.hexstring, 1, 16, 512)

    bits = buffer.flat_map { |b| (0..7).map { |n| b.bit(n) }.reverse }
    leading_bits = bits[0, difficulty].join("")
    leading_bits.split("1")[0].size
  end

  def valid_nonce?(block_hash : String, nonce : UInt64, difficulty : Int32)
    difficulty = ENV["SC_SET_DIFFICULTY"].to_i if ENV.has_key?("SC_SET_DIFFICULTY") # for unit test
    valid_pow?(block_hash, nonce, difficulty)
  end

  def block_difficulty_to_miner_difficulty(diff : Int32)
    value = (diff.to_f / 3).ceil.to_i
    Math.max(diff - value, 1)
  end

  # Dark Gravity Wave history lookback for averaging (in blocks)
  HISTORY_LOOKBACK       =      24

  # SushiChain desired block spacing (in seconds)
  POW_TARGET_SPACING     = 120_f64

  # Difficulty value to be used when there is absolutely no history reference
  DEFAULT_DIFFICULTY_TARGET      = 17_i32

  # Dark Gravity Wave based difficulty adjustment calculation (Original algorithm created by Evan Duffield)

  def block_difficulty(blockchain : Blockchain) : Int32
    actual_timespan = 0_f64
    last_block_time = 0
    past_difficulty_avg = 0_f64
    past_difficulty_avg_prev = 0_f64

    # return difficulty from env var if it has be set
    return ENV["SC_SET_DIFFICULTY"].to_i if ENV.has_key?("SC_SET_DIFFICULTY")

    # return difficulty default target if doing e2e test
    return DEFAULT_DIFFICULTY_TARGET if ENV.has_key?("SC_E2E") # for e2e test

    # return difficulty default target if chain non-existant or not enough block history
    chain = blockchain.chain
    #debug "entered block_difficulty with chain length of #{chain.size}" if chain
    if !chain || chain.size < 3
      #debug "entered block_difficulty with short initial chain (fewer than 3 blocks), returning default difficulty of #{DEFAULT_DIFFICULTY_TARGET}"
      return DEFAULT_DIFFICULTY_TARGET
    end

    # construct an average difficulty from the historical blocks and calculate elapsed time of historical blocks
    count_blocks = 0
    oldest_history_spot = Math.max(chain.size - HISTORY_LOOKBACK, 1)
    i = oldest_history_spot
    #debug "Oldest history spot: #{oldest_history_spot}"
    while i < chain.size
      block_reading = chain[i]
      if count_blocks == 0
        past_difficulty_avg = block_reading.difficulty
      else
        past_difficulty_avg = ((past_difficulty_avg_prev * count_blocks)+(block_reading.difficulty)) / (count_blocks + 1).to_f64
      end
      past_difficulty_avg_prev = past_difficulty_avg
      if last_block_time > 0
        diff = (block_reading.timestamp - last_block_time).to_f64
        if (diff > POW_TARGET_SPACING * 0.5) && (diff < POW_TARGET_SPACING * 1.5)
          actual_timespan += diff
          #debug "Had a difference of  #{diff} now actual timespan is #{actual_timespan}"
          count_blocks += 1
        else
          #debug "Had a difference of  #{diff} out of range for averaging probably due to a period of time with no miners"
        end
      end
      last_block_time = block_reading.timestamp
      i += 1
    end
    calculated_difficulty = past_difficulty_avg

    #debug "Number of blocks in history lookback: #{count_blocks}"
    #debug "calculated average difficulty: #{calculated_difficulty}"
    #debug "calculated actual timespan: #{actual_timespan}"

    if count_blocks == 0
      #debug "No valid blocks in history for averaging, returning default difficulty"
      return DEFAULT_DIFFICULTY_TARGET
    end

    # calculate what the elapsed time for the historical block generation should have been
    target_timespan = count_blocks.to_f64 * POW_TARGET_SPACING

    # calculate average block time for the history block
    # average_block_time = (actual_timespan / count_blocks).to_f64

    #debug "calculated target timespan: #{target_timespan}"
    #debug "average generation time per block: #{average_block_time} seconds"

    # Calculate the new difficulty based on actual and target timespan.
    calculated_difficulty *= target_timespan
    calculated_difficulty /= actual_timespan
    #debug "Difficulty adjusted by timespane #{calculated_difficulty}"

    calculated_difficulty_i32 = calculated_difficulty.round.to_i32

    #debug "DGW calculated difficulty adjusted by timespans (and rounded): #{calculated_difficulty_i32}"
    if calculated_difficulty_i32 < 0
      #info "DGW calculation yielded negative value, return default of #{DEFAULT_DIFFICULTY_TARGET}"
      return DEFAULT_DIFFICULTY_TARGET
    end
    calculated_difficulty_i32
  end


  include Hashes
end
