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

require "openssl/cipher"
require "crypto/bcrypt/password"

module ::Axentro::Core::Keys::BlowFish
  def self.encrypt(password, data)
    hashed_password = Crypto::Bcrypt::Password.create(password, cost: 10)
    cipher = OpenSSL::Cipher.new("bf-ecb")
    cipher.encrypt
    cipher.key = hashed_password.to_s.reverse
    cipher.random_iv
    io = IO::Memory.new
    io.write(cipher.update(data))
    io.write(cipher.final)
    {data: Base64.strict_encode(io.to_slice), salt: hashed_password.salt}
  end

  def self.decrypt(password, data, salt)
    hashed_password = Crypto::Bcrypt.new(password, salt, cost: 10).to_s.reverse
    data = Base64.decode(data)
    cipher = OpenSSL::Cipher.new("bf-ecb")
    cipher.decrypt
    cipher.key = hashed_password
    io = IO::Memory.new
    io.write(cipher.update(data))
    io.write(cipher.final)
    io.to_s
  end
end
