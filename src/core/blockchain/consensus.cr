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

module ::Axentro::Core::Consensus
  def calculate_pow_difficulty(mining_version : MiningVersion, block_hash : String, block_nonce : BlockNonce, difficulty : Int32) : Int32
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

  # returns the difficulty found for the hash and nonce given the target difficulty
  def is_nonce_valid?(mining_version : MiningVersion, block_hash : String, block_nonce : BlockNonce, difficulty : Int32) : Bool
    difficulty = ENV["AX_SET_DIFFICULTY"].to_i if ENV.has_key?("AX_SET_DIFFICULTY") # for unit test
    calculate_pow_difficulty(mining_version, block_hash, block_nonce, difficulty) == difficulty
  end

  def block_difficulty_to_miner_difficulty(diff : Int32)
    value = (diff.to_f / 3).ceil.to_i
    Math.max(diff - value, 1)
  end

  # Axentro desired block spacing (2 minutes .. 120 seconds expressed in milliseconds and seconds)
  POW_TARGET_SPACING      = 120000_f64
  POW_TARGET_SPACING_SECS =    120_i64

  MINER_DIFFICULTY_TARGET = 17

  include Hashes
end
