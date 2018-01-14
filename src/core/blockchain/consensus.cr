module ::Sushi::Core::Consensus

  DIFFICULTY = 3

  CHRS = %w(0 1 2 3 4 5 6 7 8 9 a b c d e f)

  def valid?(block_hash : String, nonce : UInt64, difficulty : Int32 = DIFFICULTY) : Bool
    param  : Int32 = 0
    prefix : String = case nonce % 16
                      when 0
                        param = 37
                        "0" * DIFFICULTY
                      when 1
                        param = 29
                        "e" * DIFFICULTY
                      when 2
                        param = 17
                        "b" * DIFFICULTY
                      when 3
                        param = 71
                        "5" * DIFFICULTY
                      when 4
                        param = 19
                        "d" * DIFFICULTY
                      when 5
                        param = 31
                        "a" * DIFFICULTY
                      when 6
                        param = 13
                        "9" * DIFFICULTY
                      when 7
                        param = 73
                        "3" * DIFFICULTY
                      when 8
                        param = 61
                        "2" * DIFFICULTY
                      when 9
                        param = 47
                        "1" * DIFFICULTY
                      when 10
                        param = 53
                        "4" * DIFFICULTY
                      when 11
                        param = 59
                        "c" * DIFFICULTY
                      when 12
                        param = 43
                        "8" * DIFFICULTY
                      when 13
                        param = 67
                        "7" * DIFFICULTY
                      when 14
                        param = 23
                        "6" * DIFFICULTY
                      else
                        param = 41
                        "f" * DIFFICULTY
                      end

    suffix : String = CHRS[(nonce + param) % 16] * DIFFICULTY

    guess_nonce = "#{block_hash}#{nonce}"
    guess_hash = sha256(guess_nonce)

    puts "prefix: #{prefix}, suffix: #{suffix}"
    puts "sha256: #{sha256(guess_nonce)}"
    puts "result: #{guess_hash[0..(difficulty-1)] == prefix} && #{guess_hash[-difficulty..-1] == suffix}"

    guess_hash[0..(difficulty-1)] == prefix && guess_hash[-difficulty..-1] == suffix
  end
end
