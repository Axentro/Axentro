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
  # SHA256 Implementation
  def valid_sha256?(block_hash : String, nonce : UInt64, difficulty : Int32) : Bool
    guess_nonce = "#{block_hash}#{nonce}"
    guess_hash = sha256(guess_nonce)
    guess_hash[0, difficulty] == "0" * difficulty
  end

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

    buffer.hexstring[0, difficulty] == "0" * difficulty
  end

  def valid_nonce?(block_hash : String, nonce : UInt64, difficulty : Int32) : Bool
    difficulty = ENV["SC_SET_DIFFICULTY"].to_i if ENV.has_key?("SC_SET_DIFFICULTY") # for unit test
    valid_scryptn?(block_hash, nonce, difficulty)
  end

  BASE_TIME = 300.0
  MIN_DIFF  =     3

  def block_difficulty(timestamp : Int64, block : Block) : Int32
    return MIN_DIFF if ENV.has_key?("SC_E2E") # for e2e test
    return ENV["SC_SET_DIFFICULTY"].to_i if ENV.has_key?("SC_SET_DIFFICULTY")

    ratio = (timestamp - block.timestamp).to_f / BASE_TIME

    return block.difficulty + 1 if ratio < 0.1
    return Math.max(Math.max(block.difficulty - 2, 1), MIN_DIFF) if ratio > 100.0
    return Math.max(Math.max(block.difficulty - 1, 1), MIN_DIFF) if ratio > 10.0

    block.difficulty
  end

  include Hashes
end
