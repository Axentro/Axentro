module ::Sushi::Core::Consensus

  DIFFICULTY = 5
  MINER_DIFFICULTY = 4

  BORDER = UInt16::MAX/8

  # guess_hash[0, difficulty] == "0" * difficulty # original

  def valid?(block_hash : String, nonce : UInt64, difficulty : Int32 = DIFFICULTY) : Bool
    guess_nonce = "#{block_hash}#{nonce}"
    guess_hash = sha256(guess_nonce)

    n0  = guess_hash[0..3].to_u16(16)
    n1  = guess_hash[4..7].to_u16(16)
    n2  = guess_hash[8..11].to_u16(16)
    n3  = guess_hash[12..15].to_u16(16)
    n4  = guess_hash[16..19].to_u16(16)
    n5  = guess_hash[20..23].to_u16(16)
    n6  = guess_hash[24..27].to_u16(16)
    n7  = guess_hash[28..31].to_u16(16)
    n8  = guess_hash[32..35].to_u16(16)
    n9  = guess_hash[36..39].to_u16(16)
    n10 = guess_hash[40..43].to_u16(16)
    n11 = guess_hash[44..47].to_u16(16)
    n12 = guess_hash[48..51].to_u16(16)
    n13 = guess_hash[52..55].to_u16(16)
    n14 = guess_hash[56..59].to_u16(16)
    n15 = guess_hash[60..63].to_u16(16)

    if n0  > BORDER &&
       n1  > BORDER &&
       n2  > BORDER &&
       n3  > BORDER &&
       n4  > BORDER &&
       n5  > BORDER &&
       n6  > BORDER &&
       n7  > BORDER &&
       n8  > BORDER &&
       n9  > BORDER &&
       n10 > BORDER &&
       n11 > BORDER &&
       n12 > BORDER &&
       n13 > BORDER &&
       n14 > BORDER &&
       n15 > BORDER

      return sha256(guess_hash)[-difficulty..-1] == "0" * difficulty
    end

    false
  end

  include Hashes
end
