module ::Sushi::Core
  # SushiChain Address Resolution System
  # todo:
  # sell
  # confirmations
  # domain validation
  # unit tests for raises
  # integrated into e2e
  # create as dApps
  # min_fee_of_action (not equal)
  class Scars
    @domains_internal : DomainMap

    def initialize
      @domains_internal = DomainMap.new
    end

    def buy?(transactions : Array(Transaction), domain_name : String, address : String, price : Int64) : Bool
      puts "scars_buy domain_name: #{domain_name}, address: #{address}, price: #{price}"

      sale_price = if domain = tmp_domains(transactions)[domain_name]?
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

      raise "domain #{domain_name} not found" unless domain = tmp_domains(transactions)[domain_name]?
      raise "domain address mismatch: #{address} vs #{domain[:address]}" unless address == domain[:address]

      puts "有効！"

      true
    end

    def tmp_domains(transactions : Array(Transaction)) : DomainMap
      tmp_domains_internal = @domains_internal.dup

      puts "  tmp_domains transactions: #{transactions.size}"

      transactions.each do |transaction|
        next if transaction.action != "scars_buy" && transaction.action != "scars_sell"

        domain_name = transaction.message
        address = transaction.senders[0][:address]
        price = transaction.senders[0][:amount]

        puts "    domain_name: #{domain_name}, address: #{address}, price: #{price}"

        case transaction.action
        when "scars_buy"
          tmp_domains_internal[domain_name] = {
            domain_name: domain_name,
            address:     address,
            price:       price,
            status:      Models::DomainStatusResolved,
          }
        when "scars_sell"
          tmp_domains_internal[domain_name] = {
            domain_name: domain_name,
            address:     address,
            price:       price,
            status:      Models::DomainStatusForSale,
          }
        end
      end

      puts "  tmp_domains <= #{tmp_domains_internal.keys.size}"

      tmp_domains_internal
    end

    # todo: confirmation
    def record(chain)
      puts "scars record"

      chain[@domains_internal.size..-1].each do |block|
        scars_transactions = block.transactions.select { |transaction|
          transaction.action == "scars_buy" ||
            transaction.action == "scars_sell"
        }

        puts "scars_transactions (#{block.index}): #{scars_transactions.size}"

        scars_transactions.each do |scars_transaction|
          domain_name = scars_transaction.message
          address = scars_transaction.senders[0][:address]
          price = scars_transaction.senders[0][:amount]

          case scars_transaction.action
          when "scars_buy"
            @domains_internal[domain_name] = {
              domain_name: domain_name,
              address:     address,
              price:       price,
              status:      Models::DomainStatusResolved,
            }
          when "scars_sell"
            @domains_internal[domain_name] = {
              domain_name: domain_name,
              address:     address,
              price:       price,
              status:      Models::DomainStatusForSale,
            }
          end
        end

        puts "recored"
        puts @domains_internal
      end
    end

    def clear
      @domains_internal.clear
    end

    def sales : Array(Models::Domain)
      @domains_internal
        .map { |domain_name, domain| domain }
        .select { |domain| domain[:status] == Models::DomainStatusForSale }
    end

    def resolve?(domain_name : String) : Models::Domain?
      @domains_internal[domain_name]?
    end

    include Core::Fees
  end
end
