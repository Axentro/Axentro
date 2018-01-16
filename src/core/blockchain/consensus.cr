module ::Sushi::Core::Consensus

  DIFFICULTY = 5
  MINER_DIFFICULTY = 4

  # simple sha256 implementation
  #
  # def valid?(block_hash : String, nonce : UInt64, difficulty : Int32 = DIFFICULTY) : Bool
  #   guess_nonce = "#{block_hash}#{nonce}"
  #   guess_hash = sha256(guess_nonce)
  #   guess_hash[0, difficulty] == "0" * difficulty
  # end

  # Simple Scrypt implementation
  # N = 16
  # r = p = 1
  def valid?(block_hash : String, nonce : UInt64, difficulty : Int32 = DIFFICULTY) : Bool
    guess_hash = scrypt(block_hash, nonce)
    guess_hash[0, difficulty] == "0" * difficulty
  end

  include Scrypt
end
