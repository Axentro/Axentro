require "big"
require "openssl"
require "openssl/digest"
require "openssl/pkcs5"

# Endian: https://github.com/crystal-lang/crystal/blob/ecf01be047920270877e696f8b70a890148a7e17/spec/std/io/byte_format_spec.cr

module ::Sushi::Core::Hashes
  ALGORITHMS = %w( sha256 ripemd160 )

  {% for a in ALGORITHMS %}
    def {{ a.id }}_from_hexstring(hexstring : String) : String
      {{ a.id }}(hexstring.hexbytes)
    end

    def {{ a.id }}(base : Array(UInt8)) : Bytes
      pointer = base.to_unsafe
      {{ a.id }}(Slice(UInt8).new(pointer, base.size))
    end

    def {{ a.id }}(base : Bytes|String) : Bytes
      base_digest = OpenSSL::Digest.new("{{ a.id.upcase }}")
      base_io = IO::Memory.new(base)

      bytes = Bytes.new(256)

      digest_io = OpenSSL::DigestIO.new(base_io, base_digest)
      digest_io.read(bytes)
      digest_io.digest
    end
  {% end %}
end

include ::Sushi::Core::Hashes

def slice_as_integer(slice : Bytes) : UInt128
  pointer = slice.pointer(1)
  pointer.as(UInt128*)[0]
end

def integer_to_bytes(int : UInt64) : Bytes
  io = IO::Memory.new(8)
  io.write_bytes(int, IO::ByteFormat::LittleEndian)
  io.rewind
  io.to_slice
end

def xor(a : Bytes, b : Bytes) : Bytes
  a.map_with_index { |aa, i| aa ^ b[i] }
end

def block_mix(a : Bytes, b : Bytes) : Array(Bytes)
  x = sha256(xor(a, b))
  y = sha256(xor(a, b))

  [x, y]
end

def ro_mix(b0 : Bytes, b1 : Bytes) : Array(Bytes)
  n = 16
  v = Array(Array(Bytes)).new
  x = block_mix(b0, b1)

  n.times do |i|
    b = [b0, b1]

    i.times do |j|
      b = block_mix(b0, b1)
    end

    v.push(b)
  end

  (n-1).times do |i|
    x = block_mix(x[0], x[1])
  end

  n.times do |i|
    k = slice_as_integer(x[1]) % n
    x = [xor(x[0], v[k][0]), xor(x[1], v[k][1])]
  end

  x
end

def scrypt(password : String, salt : UInt64)
  b = OpenSSL::PKCS5.pbkdf2_hmac_sha1(password, integer_to_bytes(salt))
  b0 = b[0, 32]
  b1 = b[32, 32]

  x = ro_mix(b0, b1)

  x0_bytes = Slice(UInt8).new(x[0].to_unsafe, x[0].size)
  x1_bytes = Slice(UInt8).new(x[1].to_unsafe, x[1].size)

  OpenSSL::PKCS5.pbkdf2_hmac_sha1(password, xor(x0_bytes, x1_bytes))
end

hoge = sha256("hoge")
fuga = sha256("fuga")

x = ro_mix(hoge, fuga)

p scrypt("test", 1020.to_u64)
