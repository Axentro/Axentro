module ::Sushi::Core::Models
  # todo: status => DomainStatus
  # 0: resolved
  # 1: for sale
  # 2: not found
  DomainStatusResolved = 0
  DomainStatusForSale  = 1
  DomainStatusNotFound = 2

  alias Domain = NamedTuple(domain_name: String, address: String, status: Int32, price: Int64)
  alias DomainMap = Hash(String, Domain)
end
