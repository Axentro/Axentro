module ::Sushi::Core::DApps::BuildIn
  #
  # SushiChain Address Resolution System
  #
  # valid suffixes
  SUFFIX = %w(sc)

  class Scars < DApp
    @domains_internal : Array(DomainMap) = Array(DomainMap).new

    def sales : Array(Models::Domain)
      domain_all = DomainMap.new

      @domains_internal.reverse.each do |domain_map|
        domain_map.each do |domain_name, domain|
          domain_all[domain_name] ||= domain
        end
      end

      domain_for_sale = domain_all
        .select { |domain_name, domain| domain[:status] == Models::DomainStatus::ForSale }
        .map { |domain_name, domain| domain }

      domain_for_sale
    end

    def resolve(domain_name : String) : Models::Domain?
      return nil if @domains_internal.size < CONFIRMATION
      resolve_for(domain_name, @domains_internal.reverse[(CONFIRMATION - 1)..-1])
    end

    def resolve_unconfirmed(domain_name : String, transactions : Array(Transaction)) : Models::Domain?
      domain_map = create_domain_map_for_transactions(transactions)

      tmp_domains_internal = @domains_internal.dup
      tmp_domains_internal.push(domain_map)

      resolve_for(domain_name, tmp_domains_internal.reverse)
    end

    def actions : Array(String)
      ["scars_buy", "scars_sell", "scars_cancel"]
    end

    def related?(action : String) : Bool
      action.starts_with?("scars_")
    end

    def valid_impl?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      case transaction.action
      when "scars_buy"
        return valid_buy?(transaction, prev_transactions)
      when "scars_sell"
        return valid_sell?(transaction, prev_transactions)
      when "scars_cancel"
        return valid_cancel?(transaction, prev_transactions)
      end

      false
    end

    def valid_buy?(transaction : Transaction, transactions : Array(Transaction)) : Bool
      raise "you must pay by #{UTXO::DEFAULT} for SCARS" unless transaction.token == UTXO::DEFAULT

      sender = transaction.senders[0]
      recipients = transaction.recipients
      domain_name = transaction.message
      address = sender[:address]
      price = sender[:amount]

      valid_domain?(domain_name)

      sale_price = if domain = resolve_unconfirmed(domain_name, transactions)
                     raise "domain #{domain_name} is not for sale now" unless domain[:status] == Models::DomainStatus::ForSale
                     raise "you have to the set a domain owner as a recipient" if recipients.size == 0
                     raise "you cannot set multiple recipients" if recipients.size > 1

                     recipient_address = recipients[0][:address]

                     raise "domain address mismatch: #{recipient_address} vs #{domain[:address]}" if recipient_address != domain[:address]

                     domain[:price]
                   else
                     raise "you cannot set a recipient since no body has bought the domain: #{domain_name}" if recipients.size > 0
                     0 # default price
                   end

      raise "the supplied price #{price} is different to expected price #{sale_price}" unless sale_price == price

      true
    end

    def valid_sell?(transaction : Transaction, transactions : Array(Transaction)) : Bool
      raise "you have to set one recipient" if transaction.recipients.size != 1

      sender = transaction.senders[0]
      domain_name = transaction.message
      address = sender[:address]
      price = sender[:amount]

      valid_domain?(domain_name)

      recipient = transaction.recipients[0]

      raise "domain #{domain_name} not found" unless domain = resolve_unconfirmed(domain_name, transactions)
      raise "domain #{domain_name} is already for sale now" if domain[:status] == Models::DomainStatus::ForSale
      raise "domain address mismatch: expected #{address} but got #{domain[:address]}" unless address == domain[:address]
      raise "address mismatch for scars_sell: expected #{address} but got #{recipient[:address]}" if address != recipient[:address]
      raise "price mismatch for scars_sell: expected #{price} but got #{recipient[:amount]}" if price != recipient[:amount]
      raise "the selling price must be 0 or higher" if price < 0

      true
    end

    def valid_cancel?(transaction : Transaction, transactions : Array(Transaction)) : Bool
      raise "you have to set one recipient" if transaction.recipients.size != 1

      sender = transaction.senders[0]
      domain_name = transaction.message
      address = sender[:address]
      price = sender[:amount]

      valid_domain?(domain_name)

      recipient = transaction.recipients[0]

      raise "domain #{domain_name} not found" unless domain = resolve_unconfirmed(domain_name, transactions)
      raise "domain #{domain_name} is not for sale" if domain[:status] != Models::DomainStatus::ForSale
      raise "domain address mismatch: expected #{address} but got #{domain[:address]}" unless address == domain[:address]
      raise "address mismatch for scars_sell: expected #{address} but got #{recipient[:address]}" if address != recipient[:address]
      raise "price mismatch for scars_sell: expected #{price} but got #{recipient[:amount]}" if price != recipient[:amount]

      true
    end

    def valid_domain?(domain_name : String) : Bool
      Core::DApps::BuildIn::Scars.valid_domain?(domain_name)
    end

    def self.valid_domain?(domain_name : String) : Bool
      unless domain_name =~ /^[a-zA-Z0-9]{1,20}\.(#{SUFFIX.join("|")})$/
        domain_rule = <<-RULE
Your domain '#{domain_name}' is not valid

1. domain name must contain only alphanumerics
2. domain name must end with one of these suffixes: #{SUFFIX}
3. domain name length must be between 1 and 20 characters (excluding suffix)
RULE
        raise domain_rule
      end

      true
    end

    def record(chain)
      chain[@domains_internal.size..-1].each do |block|
        domain_map = create_domain_map_for_transactions(block.transactions)
        @domains_internal.push(domain_map)
      end
    end

    def clear
      @domains_internal.clear
    end

    private def resolve_for(domain_name : String, domains : Array(DomainMap)) : Models::Domain?
      domains.each do |domains_internal|
        return domains_internal[domain_name] if domains_internal[domain_name]?
      end

      nil
    end

    private def create_domain_map_for_transactions(transactions : Array(Transaction)) : DomainMap
      domain_map = DomainMap.new

      transactions.each do |transaction|
        next if transaction.action != "scars_buy" &&
                transaction.action != "scars_sell" &&
                transaction.action != "scars_cancel"

        domain_name = transaction.message
        address = transaction.senders[0][:address]
        price = transaction.senders[0][:amount]

        case transaction.action
        when "scars_buy"
          domain_map[domain_name] = {
            domain_name: domain_name,
            address:     address,
            price:       price,
            status:      Models::DomainStatus::Acquired,
          }
        when "scars_sell"
          domain_map[domain_name] = {
            domain_name: domain_name,
            address:     address,
            price:       price,
            status:      Models::DomainStatus::ForSale,
          }
        when "scars_cancel"
          domain_map[domain_name] = {
            domain_name: domain_name,
            address:     address,
            price:       price,
            status:      Models::DomainStatus::Acquired,
          }
        end
      end

      domain_map
    end

    def self.fee(action : String) : Int64
      case action
      when "scars_buy"
        return 100_i64
      when "scars_sell"
        return 10_i64
      when "scars_cancel"
        return 1_i64
      end

      raise "got unknown action #{action} during getting a fee for scars"
    end

    def rpc?(call, json, context, params)
      case call
      when "scars_resolve"
        return scars_resolve(json, context, params)
      when "scars_for_sale"
        return scars_for_sale(json, context, params)
      end

      nil
    end

    def scars_resolve(json, context, params)
      domain_name = json["domain_name"].as_s
      confirmed = json["confirmed"].as_bool

      domain = confirmed ? resolve(domain_name) : resolve_unconfirmed(domain_name, [] of Transaction)

      response = if domain
                   {resolved: true, domain: domain}.to_json
                 else
                   default_domain = {domain_name: domain_name, address: "", status: Models::DomainStatus::NotFound, price: 0}
                   {resolved: false, domain: default_domain}.to_json
                 end

      context.response.print response
      context
    end

    def scars_for_sale(json, context, params)
      domain_for_sale = sales

      context.response.print domain_for_sale.to_json
      context
    end

    include Consensus
  end
end
