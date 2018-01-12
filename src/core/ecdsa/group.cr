module ::Sushi::Core::ECDSA
  abstract class Group
    abstract def _gx : BigInt
    abstract def _gy : BigInt
    abstract def _a  : BigInt
    abstract def _b  : BigInt
    abstract def _n  : BigInt
    abstract def _p  : BigInt

    def gp : Point
      Point.new(self, _gx, _gy)
    end

    def infinity : Point
      Point.new(self, BigInt.new(0), BigInt.new(0), true)
    end

    def create_key_pair
      random_key = Random::Secure.hex(64)

      return create_key_pair if random_key[0] == '0'

      secret_key = BigInt.new(random_key, base: 16)
      create_key_pair(secret_key)
    end

    def create_key_pair(secret_key : BigInt)
      public_key = gp * secret_key

      {
        secret_key: secret_key,
        public_key: public_key,
      }
    end

    def sign(secret_key : BigInt, message : String) : Array(BigInt)
      hash = BigInt.new(sha256(message), base: 16)

      random = Random::Secure.hex(64)

      return sign(secret_key, message) if random[0] == '0'

      k = BigInt.new(random, base: 16)
      p = gp * k
      r = p.x

      return sign(secret_key, message) if r == 0

      s = (mod_inv(k, _n) * (hash + secret_key * r)) % _n

      return sign(secret_key, message) if s == 0

      [r, s]
    end

    def verify(public_key : Point, message : String, r : BigInt, s : BigInt) : Bool
      hash = BigInt.new(sha256(message), base: 16)

      c = mod_inv(s, _n)

      u1 = (hash * c) % _n
      u2 = (r * c) % _n
      xy = (gp * u1) + (public_key * u2)

      v = xy.x % _n
      v == r
    end

    include ECDSA
  end
end
