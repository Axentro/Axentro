module ::Sushi::Core::Hashes
  ALGORITHMS = %w(sha256 ripemd160)

  {% for a in ALGORITHMS %}
    def {{ a.id }}_from_hexstring(hexstring : String) : Bytes
      {{ a.id }}(hexstring.hexbytes)
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
