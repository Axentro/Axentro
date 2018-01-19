module ::Sushi::Core::Consensus

  DIFFICULTY = 4
  MINER_DIFFICULTY = 3

  # SHA256 Implementation
  def _valid?(block_hash : String, nonce : UInt64, difficulty : Int32 = DIFFICULTY) : Bool
    guess_nonce = "#{block_hash}#{nonce}"
    guess_hash = sha256(guess_nonce)
    guess_hash[0, difficulty] == "0" * difficulty
  end

  N = 1 << 16
  R = 1
  P = 1
  K = 512

  # Scrypt Implementation
  def valid?(block_hash : String, nonce : UInt64, difficulty : Int32 = DIFFICULTY) : Bool
    nonce_salt = nonce.to_s(16)
    nonce_salt = "0" + nonce_salt if nonce_salt.bytesize%2 != 0

    nonce_slice = Slice(UInt8).new(nonce_salt.bytesize / 2)
    nonce_slice.size.times do |i|
      nonce_slice[i] = nonce_salt[i*2 .. i*2+1].to_u8(16)
    end

    buffer = Slice(UInt8).new(K)

    res = LibScrypt.crypto_scrypt(block_hash, block_hash.bytesize,
                                  nonce_slice, nonce_slice.size,
                                  N, R, P, buffer, K)

    raise "LibScrypt throws an error: #{res}" unless res == 0

    buffer.hexstring[0, difficulty] == "0" * difficulty
  end

  include Hashes
end
