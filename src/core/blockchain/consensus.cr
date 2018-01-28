module ::Sushi::Core::Consensus

  N = 1 << 16
  R =   1
  P =   1
  K = 512

  # Uses scrypt implementation
  def valid?(block_index : Int64, block_hash : String, nonce : UInt64, _difficulty : Int32? = nil) : Bool
    difficulty = _difficulty.nil? ? difficulty_at(block_index) : _difficulty.not_nil!

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

  def difficulty_at(block_index : Int64) : Int32
    4
  end

  def miner_difficulty_at(block_index : Int64) : Int32
    3
  end

  include Hashes
end
