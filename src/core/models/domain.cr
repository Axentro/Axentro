module ::Sushi::Core::Models
  module DomainStatus
    Acquired =  0
    ForSale  =  1
    NotFound = -1
  end

  alias Domain = NamedTuple(domain_name: String, address: String, status: Int32, price: Int64)
  alias DomainMap = Hash(String, Domain)
end
