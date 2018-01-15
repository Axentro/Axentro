module ::Sushi::Core::Consensus
  DIFFICULTY = 6
  MINER_DIFFICULTY = 5

  def valid?(block_hash : String, nonce : UInt64, difficulty : Int32 = DIFFICULTY) : Bool
    guess_nonce = "#{block_hash}#{nonce}"
    guess_hash = sha256(guess_nonce)
    guess_hash[0, difficulty] == "0" * difficulty # original

    # n0 = guess_hash[0..3].to_u16(16)
    # n1 = guess_hash[4..7].to_u16(16)
    # n2 = guess_hash[8..11].to_u16(16)
    # n3 = guess_hash[12..15].to_u16(16)
    # n4 = guess_hash[16..19].to_u16(16)
    # n5 = guess_hash[20..23].to_u16(16)
    # n6 = guess_hash[24..27].to_u16(16)
    # n7 = guess_hash[28..31].to_u16(16)
    #  
    # if n0 > UInt16::MAX/3 && n1 > UInt16::MAX/3 && n2 > UInt16::MAX/3 && n3 > UInt16::MAX/3 &&
    #    n0 > UInt16::MAX/3 && n1 > UInt16::MAX/3 && n2 > UInt16::MAX/3 && n3 > UInt16::MAX/3
    #   return guess_hash[-difficulty..-1] == "0" * difficulty
    # end
    #  
    # false
  end
end
