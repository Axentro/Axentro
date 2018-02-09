require "openssl/cipher"

module ::Sushi::Core::BlowFish
  def self.encrypt(data, password)
    cipher = OpenSSL::Cipher.new("bf-ecb")
    cipher.encrypt
    cipher.key = password
    cipher.random_iv
    io = IO::Memory.new
    io.write(cipher.update(data))
    io.write(cipher.final)
    Base64.strict_encode(io.to_slice)
  end

  def self.decrypt(data, password)
    data = Base64.decode(data)
    cipher = OpenSSL::Cipher.new("bf-ecb")
    cipher.decrypt
    cipher.key = password
    io = IO::Memory.new
    io.write(cipher.update(data))
    io.write(cipher.final)
    io.to_s
  end
end
