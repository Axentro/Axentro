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

module ::Sushi::Core::ECDSA
  abstract class Group
    abstract def _gx : BigInt
    abstract def _gy : BigInt
    abstract def _a : BigInt
    abstract def _b : BigInt
    abstract def _n : BigInt
    abstract def _p : BigInt

    def gp : Point
      Point.new(self, _gx, _gy)
    end

    def infinity : Point
      Point.new(self, BigInt.new(0), BigInt.new(0), true)
    end

    def create_key_pair
      random_key = Random::Secure.hex(32)
      secret_key = BigInt.new(random_key, base: 16)

      secret_key_hex = secret_key.to_s(16)
      return create_key_pair if secret_key_hex.hexbytes? == nil || secret_key_hex.size != 64

      key_pair = create_key_pair(secret_key)

      x = key_pair[:public_key].x.to_s(16)
      y = key_pair[:public_key].y.to_s(16)

      if x.hexbytes? == nil || y.hexbytes? == nil
        return create_key_pair
      end

      if x.size != 64 || y.size != 64
        return create_key_pair
      end

      key_pair
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

      random = create_key_pair[:secret_key]

      k = random
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
