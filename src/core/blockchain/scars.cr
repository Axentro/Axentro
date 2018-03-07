module ::Sushi::Core
  # SushiChain Address Resolution System
  # todo:
  # domain validation
  # unit tests for raises
  # integrated into e2e
  # create as dApps

  class Scars
    @domains_internal : DomainMap

    def initialize
      @domains_internal = DomainMap.new
    end

    def buy?(transactions : Array(Transaction), domain_name : String, address : String, price : Int64) : Bool
      puts "--- scars.buy? の有効性を確認 ---"
      puts "domain_name: #{domain_name}"
      puts "address: #{address}"
      puts "price: #{price}"

      sale_price = if domain = tmp_domains(transactions)[domain_name]?
                     puts "解決した既存のドメイン"
                     puts domain
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
      puts "--- scars.sell? の有効性を確認 ---"
      puts "domain_name: #{domain_name}"
      puts "address: #{address}"
      puts "price: #{price}"

      raise "domain #{domain_name} not found" unless domain = tmp_domains(transactions)[domain_name]?
      raise "domain address mismatch: #{address} vs #{domain[:address]}" unless address == domain[:address]

      puts "有効！"

      true
    end

    def tmp_domains(transactions : Array(Transaction)) : DomainMap
      tmp_domains_internal = @domains_internal.dup

      puts "transactions:"
      puts transactions

      transactions.each do |transaction|
        next if transaction.action != "scars_buy" && transaction.action != "scars_sell"

        domain_name = transaction.message
        address = transaction.senders[0][:address]
        price = transaction.senders[0][:amount] - min_fee_of_action(transaction.action)

        puts "domain_name: #{domain_name}, address: #{address}, price: #{price}"

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

      puts "tmp_domains: "
      puts tmp_domains_internal

      tmp_domains_internal
    end

    def record(chain)
      return if @domains_internal.size >= chain.size

      chain[@domains_internal.size..-1].each do |block|
        scars_transactions = block.transactions.select { |transaction|
          transaction.action == "scars_buy" ||
            transaction.action == "scars_sell"
        }

        puts "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        puts "# scars_transactions: #{scars_transactions.size}"
        puts scars_transactions
        puts "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

        scars_transactions.each do |scars_transaction|
          domain_name = scars_transaction.message
          address = scars_transaction.senders[0][:address]
          price = scars_transaction.senders[0][:amount] - min_fee_of_action(scars_transaction.action)

          puts "scars record: #{domain_name} #{address} #{price}"

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

        puts "++++++++++ recorded +++++++++++"
        puts @domains_internal
        puts "+++++++++++++++++++++++++++++++"
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
      puts "-------- resolve? called --------"
      puts "domain_name: #{domain_name}"
      puts "@domain_internal"
      puts @domains_internal
      @domains_internal[domain_name]?
    end

    include Core::Fees
  end
end
