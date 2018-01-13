module ::Sushi::Core::ECDSA
  def mod_inv(a : BigInt, mod : BigInt)
    lim, him = BigInt.new(1), BigInt.new(0)
    low, high = a % mod, mod

    while low > 1
      ratio = high / low
      nm = him - lim * ratio
      new = high - low * ratio
      him = lim
      high = low
      lim = nm
      low = new
    end

    lim % mod
  end
  
  include Hashes
end

require "./ecdsa/*"
