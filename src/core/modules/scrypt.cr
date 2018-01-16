module ::Sushi::Core::Scrypt
  N = 16

  def bytes_to_integer(bytes : Bytes)
    BigInt.new(bytes.hexstring, base: 16)
  end

  def integer_to_bytes(int : UInt64) : Bytes
    io = IO::Memory.new(8)
    io.write_bytes(int, IO::ByteFormat::BigEndian)
    io.rewind
    io.to_slice
  end

  def xor(a : Bytes, b : Bytes) : Bytes
    a.map_with_index { |aa, i| aa ^ b[i] }
  end

  def block_mix(a : Bytes, b : Bytes) : Array(Bytes)
    x = sha256(xor(a, b))
    y = sha256(xor(b, x))

    [x, y]
  end

  def ro_mix(b0 : Bytes, b1 : Bytes) : Array(Bytes)
    v = Array(Array(Bytes)).new
    x = block_mix(b0, b1)

    N.times do |i|
      b = [b0, b1]

      i.times do |j|
        b = block_mix(b0, b1)
      end

      v.push(b)
    end

    (N-1).times do |i|
      x = block_mix(x[0], x[1])
    end

    N.times do |i|
      k = bytes_to_integer(x[1]) % N
      x = [xor(x[0], v[k][0]), xor(x[1], v[k][1])]
    end

    x
  end

  def scrypt(data : String, salt : UInt64)
    b = OpenSSL::PKCS5.pbkdf2_hmac_sha1(data, integer_to_bytes(salt))
    x = ro_mix(b[0, 32], b[32, 32])

    OpenSSL::PKCS5.pbkdf2_hmac_sha1(data, xor(x[0], x[1]))
  end

  include Hashes
end
