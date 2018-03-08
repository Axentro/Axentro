module ::Sushi::Core
  # SushiChain Address Resolution System
  # todo:
  # domain validation
  # unit tests for raises
  # integrated into e2e
  # create as dApps
  # min_fee_of_action (not equal)
  class Scars
    @domains_internal : Array(DomainMap) = Array(DomainMap).new

    private def get_for(domain_name : String, domains : Array(DomainMap)) : Models::Domain?
      domains.each do |domains_internal|
        return domains_internal[domain_name] if domains_internal[domain_name]?
      end

      nil
    end

    private def create_domain_map_for_transactions(transactions : Array(Transaction)) : DomainMap
      domain_map = DomainMap.new

      transactions.each do |transaction|
        next if transaction.action != "scars_buy" && transaction.action != "scars_sell"

        domain_name = transaction.message
        address = transaction.senders[0][:address]
        price = transaction.senders[0][:amount]

        case transaction.action
        when "scars_buy"
          domain_map[domain_name] = {
            domain_name: domain_name,
            address:     address,
            price:       price,
            status:      Models::DomainStatusResolved,
          }
        when "scars_sell"
          domain_map[domain_name] = {
            domain_name: domain_name,
            address:     address,
            price:       price,
            status:      Models::DomainStatusForSale,
          }
        end
      end

      domain_map
    end

    def get(domain_name : String) : Models::Domain?
      return nil if @domains_internal.size < CONFIRMATION
      get_for(domain_name, @domains_internal.reverse[(CONFIRMATION - 1)..-1])
    end

    def get_unconfirmed(domain_name, transactions : Array(Transaction)) : Models::Domain?
      domain_map = create_domain_map_for_transactions(transactions)

      tmp_domains_internal = @domains_internal.dup
      tmp_domains_internal.push(domain_map)

      get_for(domain_name, tmp_domains_internal.reverse)
    end

    def buy?(transactions : Array(Transaction), domain_name : String, address : String, price : Int64) : Bool
      puts "scars_buy domain_name: #{domain_name}, address: #{address}, price: #{price}"

      sale_price = if domain = get_unconfirmed(domain_name, transactions)
                     raise "domain #{domain_name} is not for sale now" unless domain[:status] == Models::DomainStatusForSale
                     domain[:price]
                   else
                     0 # No body has bought
                   end

      raise "the price #{price} is different of #{sale_price}" unless sale_price == price

      puts "有効！"

      true
    end

    def sell?(transactions : Array(Transaction), domain_name : String, address : String, price : Int64) : Bool
      puts "scars_sell domain_name: #{domain_name}, address: #{address}, price: #{price}"

      raise "domain #{domain_name} not found" unless domain = get_unconfirmed(domain_name, transactions)
      raise "domain address mismatch: #{address} vs #{domain[:address]}" unless address == domain[:address]

      puts "有効！"

      true
    end

    def record(chain)
      chain[@domains_internal.size..-1].each do |block|
        domain_map = create_domain_map_for_transactions(block.transactions)
        @domains_internal.push(domain_map)
      end

      puts "---- recorded ----"
      puts @domains_internal
    end

    def clear
      @domains_internal.clear
    end

    # todo: will be deprecated
    def sales : Array(Models::Domain)
      [] of Models::Domain
    end

    include Core::Fees
  end
end
