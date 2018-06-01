# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

module ::Sushi::Core::DApps::BuildIn

  class Auth < DApp
    enum Status
      Enabled =  0
      Disabled  =  1
    end

    alias SecretCode = NamedTuple(secret_code: String, address: String, status: Status)
    alias AuthMap = Hash(String, SecretCode)

    @auth_internal : Array(AuthMap) = Array(AuthMap).new

    def setup
    end

    # def sales
    #   domain_all = DomainMap.new
    #
    #   @domains_internal.reverse.each do |domain_map|
    #     domain_map.each do |domain_name, domain|
    #       domain_all[domain_name] ||= domain
    #     end
    #   end
    #
    #   domain_all
    #     .select { |domain_name, domain| domain[:status] == Status::ForSale }
    #     .map { |domain_name, domain| scale_decimal(domain) }
    # end
    #
    # def resolve(domain_name : String, confirmation : Int32) : Domain?
    #   return nil if @domains_internal.size < confirmation
    #   resolve_for(domain_name, @domains_internal.reverse[(confirmation - 1)..-1])
    # end
    #
    # def resolve_pending(domain_name : String, transactions : Array(Transaction)) : Domain?
    #   domain_map = create_domain_map_for_transactions(transactions)
    #
    #   tmp_domains_internal = @domains_internal.dup
    #   tmp_domains_internal.push(domain_map)
    #
    #   resolve_for(domain_name, tmp_domains_internal.reverse)
    # end

    def transaction_actions : Array(String)
      ["2fa_enable", "2fa_disable"]
    end

    def transaction_related?(action : String) : Bool
      action.starts_with?("2fa_")
    end

    def valid_transaction?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      case transaction.action
      when "2fa_enable"
        return valid_enable?(transaction, prev_transactions)
      when "2fa_disable"
        return valid_disable?(transaction, prev_transactions)
      end

      false
    end

    def valid_enable?(transaction : Transaction, transactions : Array(Transaction)) : Bool
      raise "senders have to be only one for 2fa action" if transaction.senders.size != 1
      raise "you must pay by #{UTXO::DEFAULT} for 2fa" unless transaction.token == UTXO::DEFAULT

      sender = transaction.senders[0]
      recipients = transaction.recipients
      secret_code = transaction.auth_code
      address = sender[:address]
      recipient_address = recipients[0][:address]

      # valid_domain?(domain_name)
      # check that 2fa is not already enabled
      # check that supplied secret_code is valid

      # raise "2fa address mismatch: #{recipient_address} vs #{domain[:address]}" if recipient_address != domain[:address]
      raise "you cannot set multiple recipients" if recipients.size > 1

      true
    end

    def valid_disable?(transaction : Transaction, transactions : Array(Transaction)) : Bool
      raise "senders have to be only one for 2fa action" if transaction.senders.size != 1
      raise "you have to set one recipient" if transaction.recipients.size != 1

      sender = transaction.senders[0]
      auth_code = transaction.auth_code
      address = sender[:address]

      # valid_domain?(domain_name)
      # check that 2fa is already enabled
      # check that the supplied auth_code is valid - check against transaction timestamp in millis and secret_code for the address

      recipient = transaction.recipients[0]

      # raise "domain #{domain_name} not found" unless domain = resolve_pending(domain_name, transactions)
      # raise "domain #{domain_name} is already for sale now" if domain[:status] == Status::ForSale
      # raise "domain address mismatch: expected #{address} but got #{domain[:address]}" unless address == domain[:address]
      # raise "address mismatch for scars_sell: expected #{address} but got #{recipient[:address]}" if address != recipient[:address]
      # raise "price mismatch for scars_sell: expected #{price} but got #{recipient[:amount]}" if price != recipient[:amount]
      # raise "the selling price must be 0 or higher" if price < 0

      true
    end

    def valid_auth_code?(auth_code)
      true
    end

#     def valid_domain?(domain_name : String) : Bool
#       Core::DApps::BuildIn::Scars.valid_domain?(domain_name)
#     end
#
#     def self.valid_domain?(domain_name : String) : Bool
#       unless domain_name =~ /^[a-zA-Z0-9]{1,20}\.(#{SUFFIX.join("|")})$/
#         domain_rule = <<-RULE
# Your domain '#{domain_name}' is not valid
#
# 1. domain name must contain only alphanumerics
# 2. domain name must end with one of these suffixes: #{SUFFIX}
# 3. domain name length must be between 1 and 20 characters (excluding suffix)
# RULE
#         raise domain_rule
#       end
#
#       true
#     end

    def record(chain)
      chain[@auth_internal.size..-1].each do |block|
        auth_map = create_auth_map_for_transactions(block.transactions)
        @auth_internal.push(auth_map)
      end
    end

    def clear
      @auth_internal.clear
    end


    def resolve(address : String, confirmation : Int32) : SecretCode?
      return nil if @auth_internal.size < confirmation
      resolve_for(address, @auth_internal.reverse[(confirmation - 1)..-1])
    end

    private def resolve_for(address : String, auths : Array(AuthMap)) : SecretCode?
      auths.each do |auth_internal|
        return auth_internal[address] if auth_internal[address]?
      end

      nil
    end

    private def create_auth_map_for_transactions(transactions : Array(Transaction)) : AuthMap
      auth_map = AuthMap.new

      transactions.each do |transaction|
        next if transaction.action != "2fa_enable" &&
                transaction.action != "2fa_disable"


        secret_code = transaction.auth_code
        address = transaction.senders[0][:address]

        case transaction.action
        when "2fa_enable"
          auth_map[address] = {
            secret_code: secret_code,
            address:     address,
            status:      Status::Enabled,
          }
        when "2fa_disable"
          auth_map[address] = {
            secret_code: secret_code,
            address:     address,
            status:      Status::Disabled,
          }
        end
      end

      auth_map
    end

    def self.fee(action : String) : Int64
      case action
      when "2fa_enable"
        return scale_i64("0.0001")
      when "2fa_disable"
        return scale_i64("0.0001")
      end

      raise "got unknown action #{action} during getting a fee for 2fa"
    end

    def define_rpc?(call, json, context, params)
      case call
      when "2fa_resolve"
        return resolve_2fa(json, context, params)
      end

      nil
    end

    def resolve_2fa(json, context, params)
      address = json["address"].as_s
      confirmation = json["confirmation"].as_i

      context.response.print api_success(resolve_2fa_impl(address, confirmation))
      context
    end

    def resolve_2fa_impl(address : String, confirmation : Int32)
      secret_code = resolve(address, confirmation)

      if secret_code
        {resolved: true, confirmation: confirmation, secret_code: secret_code}
      else
        default_secret_code = {secret_code: "", address: address, status: Status::Disabled}
        {resolved: false, confirmation: confirmation, secret_code: default_secret_code}
      end
    end

    # def scars_for_sale(json, context, params)
    #   context.response.print api_success(scars_for_sale_impl)
    #   context
    # end
    #
    # def scars_for_sale_impl
    #   sales
    # end

    # def scale_decimal(domain : Domain)
    #   {
    #     domain_name: domain[:domain_name],
    #     address:     domain[:address],
    #     status:      domain[:status],
    #     price:       scale_decimal(domain[:price]),
    #   }
    # end
    #
    # include Consensus
  end
end
