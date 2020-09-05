# Copyright © 2017-2018 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

module ::Axentro::Core::DApps::BuildIn
  #
  # Axentro Address Resolution System
  #
  # valid suffixes
  SUFFIX = %w(sc)

  enum Status
    ACQUIRED
    FOR_SALE
    NOT_FOUND = -1
  end

  alias Domain = NamedTuple(domain_name: String, address: String, status: Status, price: Int64, block: Int64)
  alias DomainResult = NamedTuple(domain_name: String, address: String, status: Status, price: String, block: Int64)
  alias DomainMap = Hash(String, Domain)

  class Scars < DApp
    def setup
    end

    def resolve_pending(domain_name : String, transactions : Array(Transaction)) : Domain?
      domain_map = create_domain_map_for_transactions(transactions)
      domain_map[domain_name]? || resolve_for(domain_name)
    end

    def transaction_actions : Array(String)
      ["scars_buy", "scars_sell", "scars_cancel"]
    end

    def transaction_related?(action : String) : Bool
      action.starts_with?("scars_")
    end

    def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
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
      raise "senders can only be 1 for scars action" if transaction.senders.size != 1
      raise "you must pay by #{UTXO::DEFAULT} for SCARS" unless transaction.token == UTXO::DEFAULT

      sender = transaction.senders[0]
      recipients = transaction.recipients
      domain_name = transaction.message
      price = sender[:amount]

      valid_domain?(domain_name)

      sale_price = if domain = resolve_pending(domain_name, transactions)
                     raise "domain #{domain_name} is not for sale now" unless domain[:status] == Status::FOR_SALE
                     raise "you have to the set a domain owner as a recipient" if recipients.size == 0
                     raise "you cannot set multiple recipients" if recipients.size > 1

                     recipient_address = recipients[0][:address]

                     raise "domain address mismatch: #{recipient_address} vs #{domain[:address]}" if recipient_address != domain[:address]

                     domain[:price]
                   else
                     raise "you cannot set a recipient since nobody has bought the domain: #{domain_name}" if recipients.size > 0
                     0 # default price
                   end

      raise "the supplied price #{price} is different than the expected price #{sale_price}" unless sale_price == price

      true
    end

    def valid_sell?(transaction : Transaction, transactions : Array(Transaction)) : Bool
      raise "senders can only be 1 for scars action" if transaction.senders.size != 1
      raise "you have to set one recipient" if transaction.recipients.size != 1

      sender = transaction.senders[0]
      domain_name = transaction.message
      address = sender[:address]
      price = sender[:amount]

      valid_domain?(domain_name)

      recipient = transaction.recipients[0]

      raise "domain #{domain_name} not found" unless domain = resolve_pending(domain_name, transactions)
      raise "domain #{domain_name} is already for sale" if domain[:status] == Status::FOR_SALE
      raise "domain address mismatch: expected #{address} but got #{domain[:address]}" unless address == domain[:address]
      raise "address mismatch for scars_sell: expected #{address} but got #{recipient[:address]}" if address != recipient[:address]
      raise "price mismatch for scars_sell: expected #{price} but got #{recipient[:amount]}" if price != recipient[:amount]
      raise "the selling price must be 0 or higher" if price < 0

      true
    end

    def valid_cancel?(transaction : Transaction, transactions : Array(Transaction)) : Bool
      raise "senders can only be 1 for scars action" if transaction.senders.size != 1
      raise "you have to set one recipient" if transaction.recipients.size != 1

      sender = transaction.senders[0]
      domain_name = transaction.message
      address = sender[:address]
      price = sender[:amount]

      valid_domain?(domain_name)

      recipient = transaction.recipients[0]

      raise "domain #{domain_name} not found" unless domain = resolve_pending(domain_name, transactions)
      raise "domain #{domain_name} is not for sale" if domain[:status] != Status::FOR_SALE
      raise "domain address mismatch: expected #{address} but got #{domain[:address]}" unless address == domain[:address]
      raise "address mismatch for scars_cancel: expected #{address} but got #{recipient[:address]}" if address != recipient[:address]
      raise "price mismatch for scars_cancel: expected #{price} but got #{recipient[:amount]}" if price != recipient[:amount]

      true
    end

    def valid_domain?(domain_name : String) : Bool
      Core::DApps::BuildIn::Scars.valid_domain?(domain_name)
    end

    def self.valid_domain?(domain_name : String) : Bool
      unless domain_name =~ /^[a-zA-Z0-9]{1,20}\.(#{SUFFIX.join("|")})$/
        domain_rule = <<-RULE
    Your domain '#{domain_name}' is not valid

    1. domain name can only contain only alphanumerics
    2. domain name must end with one of these suffixes: #{SUFFIX}
    3. domain name length must be between 1 and 20 characters (excluding suffix)
    RULE
        raise domain_rule
      end

      true
    end

    def record(chain)
    end

    def clear
    end

    def resolve_for(domain_name : String) : Domain?
      database.get_domain_map_for(domain_name)[domain_name]?
    end

    def lookup_for(address : String) : Array(Domain)
      database.get_domain_map_for_address(address).map { |_, domain| domain }
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
            status:      Status::ACQUIRED,
            block:       0_i64,
          }
        when "scars_sell"
          domain_map[domain_name] = {
            domain_name: domain_name,
            address:     address,
            price:       price,
            status:      Status::FOR_SALE,
            block:       0_i64,
          }
        when "scars_cancel"
          domain_map[domain_name] = {
            domain_name: domain_name,
            address:     address,
            price:       price,
            status:      Status::ACQUIRED,
            block:       0_i64,
          }
        end
      end

      domain_map
    end

    def self.fee(action : String) : Int64
      case action
      when "scars_buy"
        return scale_i64("0.001")
      when "scars_sell"
        return scale_i64("0.0001")
      when "scars_cancel"
        return scale_i64("0.0001")
      end

      raise "got unknown action #{action} while getting a fee for scars"
    end

    def define_rpc?(call, json, context, params) : HTTP::Server::Context?
      case call
      when "scars_resolve"
        return scars_resolve(json, context, params)
      when "scars_for_sale"
        return scars_for_sale(json, context, params)
      when "scars_lookup"
        return scars_lookup(json, context, params)
      end

      nil
    end

    def scars_resolve(json, context, params)
      domain_name = json["domain_name"].as_s

      context.response.print api_success(scars_resolve_impl(domain_name))
      context
    end

    def scars_resolve_impl(domain_name : String)
      domain = resolve_for(domain_name)

      if domain
        confirmation = database.get_confirmations(domain[:block])
        {resolved: true, confirmation: confirmation, domain: scale_decimal(domain)}
      else
        default_domain = {domain_name: domain_name, address: "", status: Status::NOT_FOUND, price: "0.0"}
        {resolved: false, confirmation: 0, domain: default_domain}
      end
    end

    def scars_for_sale(json, context, params)
      context.response.print api_success(scars_for_sale_impl)
      context
    end

    def scars_for_sale_impl
      database.get_domains_for_sale.map { |d| scale_decimal(d) }
    end

    def scars_lookup(json, context, params)
      address = json["address"].as_s

      context.response.print api_success(scars_lookup_impl(address))
      context
    end

    def scars_lookup_impl(address : String)
      domains = lookup_for(address)
      domain_results = Array(DomainResult).new

      domains.each do |domain|
        domain_results << DomainResult.new(
          domain_name: domain[:domain_name],
          address: domain[:address],
          status: domain[:status],
          price: scale_decimal(domain[:price]),
          block: domain[:block])
      end
      {address: address, domains: domain_results}
    end

    def scale_decimal(domain : Domain)
      {
        domain_name: domain[:domain_name],
        address:     domain[:address],
        status:      domain[:status],
        price:       scale_decimal(domain[:price]),
        block:       domain[:block],
      }
    end

    def on_message(action : String, from_address : String, content : String, from = nil)
      false
    end

    include Consensus
  end
end
