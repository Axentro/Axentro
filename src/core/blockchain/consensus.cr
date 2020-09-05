# Copyright © 2017-2018 The Axentro Core developers
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

module ::Axentro::Core::Consensus

  def valid_pow?(block_hash : String, block_nonce : BlockNonce, difficulty : Int32) : Int32
    nonce_salt = block_nonce.to_u64.to_s(16)
    nonce_salt = "0" + nonce_salt if nonce_salt.bytesize % 2 != 0

    nonce_slice = Slice(UInt8).new((nonce_salt.bytesize / 2).to_i64)
    nonce_slice.size.times do |i|
      nonce_slice[i] = nonce_salt[i*2..i*2 + 1].to_u8(16)
    end

    buffer = Argon2::Engine.raw_hash_buffer(
      Argon2::Engine::EngineType::ARGON2ID, block_hash, nonce_slice.hexstring, 1, 16, 512)

    bits = buffer.flat_map { |b| (0..7).map { |n| b.bit(n) }.reverse }
    leading_bits = bits[0, difficulty].join("")
    leading_bits.split("1")[0].size
  end

  def valid_nonce?(block_hash : String, block_nonce : BlockNonce, difficulty : Int32)
    difficulty = ENV["SC_SET_DIFFICULTY"].to_i if ENV.has_key?("SC_SET_DIFFICULTY") # for unit test
    valid_pow?(block_hash, block_nonce, difficulty)
  end

  def block_difficulty_to_miner_difficulty(diff : Int32)
    value = (diff.to_f / 3).ceil.to_i
    Math.max(diff - value, 1)
  end

  # Dark Gravity Wave history lookback for averaging (in blocks)
  HISTORY_LOOKBACK       =      24

  # Axentro desired block spacing (2 minutes .. 120 seconds expressed in milliseconds and seconds)
  POW_TARGET_SPACING      = 120000_f64
  POW_TARGET_SPACING_SECS = 120_i64

  # Difficulty value to be used when there is absolutely no history reference
  DEFAULT_DIFFICULTY_TARGET      = 17_i32

  # Dark Gravity Wave based difficulty adjustment calculation (Original algorithm created by Evan Duffield)

  def block_difficulty(blockchain : Blockchain) : Int32
    actual_timespan = 0_f64
    calculated_difficulty = 0_f64

    # return difficulty from env var if it has be set
    return ENV["SC_SET_DIFFICULTY"].to_i if ENV.has_key?("SC_SET_DIFFICULTY")

    # return difficulty default target if chain non-existant or not enough block history
    chain = blockchain.chain.select(&.is_slow_block?)
    #debug "entered block_difficulty with chain length of #{chain.size}" if chain
    if !chain || chain.size < 3
      #debug "entered block_difficulty with short initial chain (fewer than 3 blocks), returning default difficulty of #{DEFAULT_DIFFICULTY_TARGET}"
      return DEFAULT_DIFFICULTY_TARGET
    end

    # construct an average difficulty from the historical blocks and calculate elapsed time of historical blocks
    count_blocks = 0
    oldest_history_spot = Math.max(chain.size - HISTORY_LOOKBACK, 1)
    i = oldest_history_spot
    last_block_time = chain[i].as(SlowBlock).timestamp
    #debug "Oldest history spot: #{oldest_history_spot}"
    while i < chain.size
      block_reading = chain[i].as(SlowBlock)
      calculated_difficulty = calculate_running_difficulty_avg(calculated_difficulty, block_reading.difficulty, count_blocks)
      new_timespan = accumulate_timespan(actual_timespan, block_reading.timestamp, last_block_time)
      count_blocks += 1 if new_timespan > actual_timespan
      actual_timespan = new_timespan
      last_block_time = block_reading.timestamp
      i += 1
    end

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

  def calculate_running_difficulty_avg(calculated_difficulty : Float64, this_block_difficulty : Int32, count_blocks : Int32) : Float64
    if count_blocks == 0
      calculated_difficulty = this_block_difficulty.to_f64
    else
      calculated_difficulty = ((calculated_difficulty * count_blocks)+(this_block_difficulty)) / (count_blocks + 1).to_f64
    end
    calculated_difficulty
  end

  def accumulate_timespan(current_timespan : Float64, this_block_timestamp : Int64, last_block_time : Int64) : Float64
    time_diff = (this_block_timestamp - last_block_time).to_f64
    if (time_diff > POW_TARGET_SPACING * 0.5) && (time_diff < POW_TARGET_SPACING * 1.5)
      accumulated_timespan = current_timespan + time_diff
      #debug "Had a difference of  #{time_diff} now actual timespan is #{accumulated_timespan}"
    else
      accumulated_timespan = current_timespan
      #debug "Had a difference of  #{time_diff} out of range for averaging probably due to a period of time with no miners"
    end
    accumulated_timespan
  end

  include Hashes
end
