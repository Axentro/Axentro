module ::Sushi::Core::Models
  # todo: status => DomainStatus
  # 0: acquired
  # 1: for sale
  DomainStatusResolved = 0
  DomainStatusForSale  = 1

  alias Domain = NamedTuple(domain_name: String, address: String, status: Int32, price: Int64)
  alias DomainMap = Hash(String, Domain)
end
