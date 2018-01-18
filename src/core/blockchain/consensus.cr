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

    hash = ::Scrypt::Engine.crypto_scrypt(block_hash, nonce.to_s(16), N, R, P, K)
    hash[0, difficulty] == "0" * difficulty
  end

  include Hashes
end
