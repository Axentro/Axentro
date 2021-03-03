# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

module ::Axentro::Core::Hashes
  def sha256(base : Bytes | String) : String
    hash = OpenSSL::Digest.new("SHA256")
    hash.update(base)
    hash.final.hexstring
  end

  def ripemd160(base : Bytes | String) : String
    hash = OpenSSL::Digest.new("RIPEMD160")
    hash.update(base)
    hash.final.hexstring
  end

  def argon2(base : String) : String
    Argon2::Engine.hash_argon2id_raw(base, "AXENTRO_BLOCKCHAIN", 1, 4)
  end
end
