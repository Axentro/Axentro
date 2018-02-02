require "./src/core"

include ::Sushi::Core::Consensus

block = %{"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015adba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015adba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015adba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad}

puts sha256(block).hexstring

require "openssl"
  
hash = OpenSSL::Digest.new("SHA256")
hash.update(block)
p hash.hexdigest
