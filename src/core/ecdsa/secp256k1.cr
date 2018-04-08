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
  class Secp256k1 < Group
    def _gx : BigInt
      BigInt.new("79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798", base: 16)
    end

    def _gy : BigInt
      BigInt.new("483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8", base: 16)
    end

    def _a : BigInt
      BigInt.new("0000000000000000000000000000000000000000000000000000000000000000", base: 16)
    end

    def _b : BigInt
      BigInt.new("0000000000000000000000000000000000000000000000000000000000000007", base: 16)
    end

    def _n : BigInt
      BigInt.new("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141", base: 16)
    end

    def _p : BigInt
      BigInt.new("fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f", base: 16)
    end
  end
end
