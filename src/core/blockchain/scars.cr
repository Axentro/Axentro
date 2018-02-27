module ::Sushi::Core
  # SushiChain Address Resolution System
  # todo:
  # integrated into blockchain
  # integrated into rpc
  # integrated into sushi cli
  # domain validation
  # unit tests for raises
  # integrated into e2e
  class Scars
    @domains : DomainMap

    def initialize
      @domains = DomainMap.new
    end

    def buy(domain_name : String, address : String, price : Int64) : Bool
      sale_price = if domain = @domains[domain_name]?
                     raise "domain #{domain_name} is not for sale now" unless domain[:status] == Models::DomainStatusForSale
                     domain[:price]
                   else
                     0 # No body has bought
                   end

      raise "the price #{price} is different of #{sale_price}" unless sale_price == price

      @domains[domain_name] = {
        domain_name: domain_name,
        address:     address,
        price:       price,
        status:      Models::DomainStatusResolved,
      }

      true
    end

    def sell(domain_name : String, address : String, price : Int64) : Bool
      raise "domain #{domain_name} not found" unless domain = @domains[domain_name]?
      raise "domain address mismatch: #{address} vs #{domain[:address]}" unless address == domain[:address]

      @domains[domain_name] = {
        domain_name: domain_name,
        address:     address,
        price:       price,
        status:      Models::DomainStatusForSale,
      }

      true
    end

    def sales : Array(Models::Domain)
      @domains
        .map { |domain_name, domain| domain }
        .select { |domain| domain[:status] == Models::DomainStatusForSale }
    end

    def resolve(domain_name : String) : Models::Domain?
      @domains[domain_name]?
    end
  end
end
