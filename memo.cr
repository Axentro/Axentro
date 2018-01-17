# Endian: https://github.com/crystal-lang/crystal/blob/ecf01be047920270877e696f8b70a890148a7e17/spec/std/io/byte_format_spec.cr
# https://blog.visvirial.com/articles/519

require "./src/core"

include ::Sushi::Core::Scrypt

p scrypt("test", 1020.to_u64)
p bytes_to_integer(integer_to_bytes(100.to_u64))
