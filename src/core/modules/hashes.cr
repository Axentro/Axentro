module ::Sushi::Core::Hashes
  def sha256(base : Bytes | String) : String
    hash = OpenSSL::Digest.new("SHA256")
    hash.update(base)
    hash.hexdigest
  end

  def ripemd160(base : Bytes | String) : String
    hash = OpenSSL::Digest.new("RIPEMD160")
    hash.update(base)
    hash.hexdigest
  end
end
