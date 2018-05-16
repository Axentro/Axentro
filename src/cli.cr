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

require "option_parser"
require "file_utils"
require "colorize"
require "yaml"
require "uri"

require "./core"
require "./cli/helps"
require "./cli/modules"

module ::Sushi::Interface
  alias SushiAction = NamedTuple(name: String, desc: String)

  TOKEN_DEFAULT = Core::DApps::BuildIn::UTXO::DEFAULT

  abstract class CLI
    def initialize(
      @sushi_action : SushiAction,
      @parents : Array(SushiAction)
    )
    end

    def puts_help(message = "showing help message.", exit_code = -1)
      available_sub_actions =
        sub_actions.map { |a| " - #{light_green("%-20s" % a[:name])} | #{"%-40s" % a[:desc]}" }.join("\n")
      available_sub_actions = "nothing" if available_sub_actions == ""

      message_size = message.split("\n").max_by { |m| m.size }.size
      messages = message.split("\n").map { |m| white_bg(black(" %-#{message_size}s " % m)) }

      puts "\n" +
           "#{light_magenta("> " + command_line)} | #{@sushi_action[:desc]}\n\n" +
           "#{white_bg(black(" " + "-" * message_size + " "))}\n" +
           messages.join("\n") + "\n" +
           "#{white_bg(black(" " + "-" * message_size + " "))}\n\n" +
           "available sub actions\n" +
           available_sub_actions +
           "\n\n" +
           "available options\n" +
           (option_parser.nil? ? "nothing" : option_parser.to_s) +
           "\n\n"

      exit exit_code
    end

    def get_wallet(wallet_path, wallet_password) : Core::Wallet
      begin
        Core::Wallet.from_path(wallet_path)
      rescue Core::WalletException
        password_from_env = ENV["SC_WALLET_PASSWORD"]?
        password = password_from_env || wallet_password

        unless password
          puts_help(HELP_WALLET_PASSWORD)
        end

        wallet = Core::EncryptedWallet.from_path(wallet_path)
        Core::Wallet.from_json(Core::Wallet.decrypt(password, wallet))
      end
    end

    def command_line
      return @sushi_action[:name] if @parents.size == 0
      @parents.map { |a| a[:name] }.join(" ") + " " + @sushi_action[:name]
    end

    def next_parents : Array(SushiAction)
      @parents.concat([@sushi_action])
    end

    def sub_action_names : Array(String)
      sub_actions.map { |a| a[:name] }
    end

    def run
      puts_help if ARGV.size > 0 && ARGV[0] == "help"

      action_name = if ARGV.size > 0 && !ARGV[0].starts_with?('-')
                      ARGV.shift
                    end

      if ARGV.size > 0 && ARGV[0].starts_with?('-')
        if parser = option_parser
          parser.parse!
        end
      end

      run_impl(action_name)
    rescue e : Exception
      if error_message = e.message
        puts_error(e.message)
      end

      puts_error(e.backtrace.join("\n"))
    end

    def specify_sub_action!(_sub_action : String? = nil)
      if sub_action = _sub_action
        puts_help("invalid sub action \"#{sub_action}\"")
      else
        puts_help("specify a sub action in #{sub_action_names}")
      end
    end

    def option_error(option_name : String, parser : OptionParser)
      puts_error("please specify #{option_name}")
      puts ""
      puts parser.to_s
      exit -1
    end

    def rpc(node, payload : String) : String
      res = HTTP::Client.post("#{node}/rpc", HTTP::Headers.new, payload)
      verify_response!(res)
    end

    def verify_response!(res) : String
      unless body = res.body
        puts_error "returned body is empty"
        exit -1
      end

      json = JSON.parse(body)

      if json["status"].as_s == "error"
        puts_error json["reason"].as_s
        exit -1
      end

      unless res.status_code == 200
        puts_error "failed to call an API."
        puts_error res.body
        exit -1
      end

      json["result"].to_json
    end

    def add_transaction(node : String,
                        action : String,
                        wallets : Array(Core::Wallet),
                        senders : SendersDecimal,
                        recipients : RecipientsDecimal,
                        message : String,
                        token : String)
      raise "mimatch for wallet size and sender's size" if wallets.size != senders.size

      unsigned_transaction =
        create_unsigned_transaction(node, action, senders, recipients, message, token)

      signed_transaction = sign(wallets, unsigned_transaction)

      payload = {
        call:        "create_transaction",
        transaction: signed_transaction,
      }.to_json

      rpc(node, payload)

      unless __json
        puts_success "successfully create your transaction!"
        puts_success "=> #{signed_transaction.id}"
      else
        puts signed_transaction.to_json
      end
    end

    def create_unsigned_transaction(node : String,
                                    action : String,
                                    senders : SendersDecimal,
                                    recipients : RecipientsDecimal,
                                    message : String,
                                    token : String) : Core::Transaction
      payload = {
        call:       "create_unsigned_transaction",
        action:     action,
        senders:    senders,
        recipients: recipients,
        message:    message,
        token:      token,
      }.to_json

      body = rpc(node, payload)

      Core::Transaction.from_json(body)
    end

    def sign(wallets : Array(Core::Wallet), transaction : Core::Transaction) : Core::Transaction
      transaction.as_signed(wallets)
    end

    def resolve_internal(node, domain, confirmed : Bool = true) : JSON::Any
      payload = {call: "scars_resolve", domain_name: domain, confirmed: confirmed}.to_json

      body = rpc(node, payload)
      JSON.parse(body)
    end

    abstract def sub_actions : Array(SushiAction)
    abstract def option_parser : OptionParser?
    abstract def run_impl(action_name : String?) : OptionParser?

    include Helps
    include Logger
    include Core::TransactionModels
    include Common::Denomination
  end
end
