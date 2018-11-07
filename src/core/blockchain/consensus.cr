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
  N = 1 << 16
  R =   1
  P =   1
  K = 512

  # Scrypt Implementation
  def valid_scryptn?(block_hash : String, nonce : UInt64, difficulty : Int32) : Bool
    nonce_salt = nonce.to_s(16)
    nonce_salt = "0" + nonce_salt if nonce_salt.bytesize % 2 != 0

    nonce_slice = Slice(UInt8).new(nonce_salt.bytesize / 2)
    nonce_slice.size.times do |i|
      nonce_slice[i] = nonce_salt[i*2..i*2 + 1].to_u8(16)
    end

    buffer = Slice(UInt8).new(K)

    res = LibScrypt.crypto_scrypt(block_hash, block_hash.bytesize,
      nonce_slice, nonce_slice.size,
      N, R, P, buffer, K)

    raise "LibScrypt throws an error: #{res}" unless res == 0

    bits = buffer.flat_map { |b| (0..7).map { |n| b.bit(n) }.reverse }

    bits[0, difficulty].join("") == "0" * difficulty
  end

  def valid_nonce?(block_hash : String, nonce : UInt64, difficulty : Int32) : Bool
    difficulty = ENV["SC_SET_DIFFICULTY"].to_i if ENV.has_key?("SC_SET_DIFFICULTY") # for unit test
    valid_scryptn?(block_hash, nonce, difficulty)
  end

  BLOCK_TARGET_LOWER  = 10_i64
  BLOCK_TARGET_UPPER  = 40_i64
  BLOCK_AVERAGE_LIMIT =    720

  def block_difficulty(timestamp : Int64, elapsed_block_time : Int64, block : Block, block_averages : Array(Int64)) : Int32
    return 3 if ENV.has_key?("SC_E2E") # for e2e test
    return ENV["SC_SET_DIFFICULTY"].to_i if ENV.has_key?("SC_SET_DIFFICULTY")

    block_averages = block_averages.select { |a| a > 0_i64 }
    block_averages.delete_at(0) if block_averages.size > 0
    # return 10 unless block_averages.size > 0

    debug "elapsed block time was: #{elapsed_block_time} secs"

    block_average = block_averages.reduce { |a, b| a + b } / block_averages.size
    current_target = if block_averages.size < BLOCK_AVERAGE_LIMIT
                       debug "using elapsed block time as block averages: #{block_averages.size} is less than cache limit: #{BLOCK_AVERAGE_LIMIT}"
                       elapsed_block_time
                     else
                       debug "using block average time as block averages: #{block_averages.size} has exceeded cache limit: #{BLOCK_AVERAGE_LIMIT}"
                       block_average
                     end

    if current_target > BLOCK_TARGET_UPPER
      new_difficulty = Math.max(block.next_difficulty - 1, 1)
      debug "reducing difficulty from '#{block.next_difficulty}' to '#{new_difficulty}' with block average of (#{block_average} secs)"
      new_difficulty
    elsif current_target < BLOCK_TARGET_LOWER
      new_difficulty = block.next_difficulty + 1
      debug "increasing difficulty from '#{block.next_difficulty}' to '#{new_difficulty}' with block average of (#{block_average} secs)"
      new_difficulty
    else
      debug "maintaining block difficulty at '#{block.next_difficulty}' with block average: (#{block_average} secs)"
      block.next_difficulty
    end
  rescue Enumerable::EmptyError
    block.next_difficulty
  end

  include Hashes
end
