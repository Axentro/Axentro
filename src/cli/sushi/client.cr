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

module ::Sushi::Interface::Sushi
  class Client < CLI
    @node : String?
    @client : Core::Client?
    @wallet : Core::Wallet?

    COMMANDS = [
      {
        command: "message [address] [message]",
        desc:    "send a message for the address",
        regex:   /^message\s(.+?)\s(.+)$/,
      },
      {
        command: "send [address] [token] [amount] [fee] [message]",
        desc:    "send the amount of the token to the address",
        regex:   /^send\s(.+?)\s(.+?)\s(.+?)\s(.+?)\s(.+)$/,
      },
      {
        command: "amount [token] [confirmation]",
        desc: "show the amount of the token of the client for the confirmation",
        regex: /^amount\s(.+?)\s(\d+)$/,
      },
      {
        command: "fee",
        desc:    "show transaction fees for each action",
        regex:   /^fee$/,
      },
      {
        command: "help",
        desc:    "show help message",
        regex:   /^help$/,
      },
    ]

    def find_command(name : String)
      unless command = COMMANDS.find { |command| command[:command].split(" ")[0] == name }
        raise "failed to find #{name} as a command"
      end

      command
    end

    def sub_actions
      [] of SushiAction
    end

    def option_parser
      create_option_parser([
        Options::CONNECT_NODE,
        Options::CONFIG_NAME,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
      ])
    end

    def client : Core::Client
      @client.not_nil!
    end

    def run_impl(action_name)
      puts_help(HELP_CONNECTING_NODE) unless @node = __connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = __wallet_path

      @wallet = get_wallet(wallet_path, __wallet_password)

      node_uri = URI.parse(@node.not_nil!)
      use_ssl = (node_uri.scheme == "https")

      @client = Core::Client.new(node_uri.host.not_nil!, node_uri.port.not_nil!, use_ssl, @wallet.not_nil!)

      client.run

      gets_command
    end

    def gets_command
      while input = STDIN.gets
        send_command(input)
      end
    end

    def send_command(input : String)
      command = input.split(" ", 2)[0]

      case command
      when "message"
        message(input)
      when "send"
        send(input)
      when "amount"
        amount(input)
      when "fee"
        fee(input)
      when "help"
        show_help
      else
        puts ""
        puts "  unknown command #{yellow(command)} (will be ignored.)"
        puts "  input `> help` to show available commands"
        puts ""
        client.show_cursor
      end
    rescue e : Exception
      puts ""
      puts "  #{red("error happens!")}"
      puts "  the reason is '#{red(e.message)}'."
      puts "  input `> help` to show available commands"
      puts ""
      client.show_cursor
    end

    def message(input : String)
      command = find_command("message")

      unless input =~ command[:regex]
        raise "make sure your input `> #{command[:command]}`"
      end

      to = $1.to_s
      message = $2.to_s
      message_print = light_green(message[0..9]) + (message.size > 10 ? "..." : "")

      puts ""
      puts "send a message \"#{message_print}\" to #{light_green(to + "...")}"
      puts ""

      client.message(to, message)
    end

    def send(input : String)
      command = find_command("send")

      unless input =~ command[:regex]
        raise "make sure your input `> #{command[:command]}`"
      end

      address = $1.to_s
      token = $2.to_s
      amount = $3.to_s
      fee = $4.to_s
      message = $5.to_s

      to_address = Address.from(address, "recipient")
      wallets = [@wallet.not_nil!]

      senders = SendersDecimal.new
      senders.push(
        {
          address:    wallets[0].address,
          public_key: wallets[0].public_key,
          amount:     amount,
          fee:        fee,
          sign_r:     "0",
          sign_s:     "0",
        }
      )

      recipients = RecipientsDecimal.new
      recipients.push(
        {
          address: address,
          amount:  amount,
        }
      )

      puts ""
      puts "send #{amount} of #{token} to #{address}"
      puts ""

      add_transaction(@node.not_nil!, "send", wallets, senders, recipients, message, token)

      puts ""

      client.message(address, message)
    end

    def amount(input : String)
      command = find_command("amount")

      unless input =~ command[:regex]
        raise "make sure your input `> #{command[:command]}`"
      end

      token = $1.to_s
      confirmation = $2.to_i

      client.amount(token, confirmation)
    end

    def fee(input : String)
      command = find_command("fee")

      unless input =~ command[:regex]
        raise "make sure your input `> #{command[:command]}`"
      end

      puts ""
      puts "show transaction fees for each action"
      puts ""

      client.fee
    end

    def show_help
      puts ""
      puts "  available commands"
      puts ""

      COMMANDS.each do |command|
        puts "  - #{command[:command]}"
        puts "    #{command[:desc]}"
        puts ""
      end

      client.show_cursor
    end

    include Core::Protocol
    include GlobalOptionParser
  end
end
