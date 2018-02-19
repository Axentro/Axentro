require "../cli"
require "./sushi/*"

module ::Sushi::Interface::Sushi
  class Root < CLI
    def sub_actions
      [
        {
          name: "wallet",
          desc: "create, encrypt or decrypt your wallet",
        },
        {
          name: "blockchain",
          desc: "get a whole blockchain or each block",
        },
        {
          name: "transaction",
          desc: "get or create transactions",
        },
        {
          name: "config",
          desc: "save default configuration used by sushi, sushid and sushim",
        },
      ]
    end

    def option_parser
      nil
    end

    def run_impl(action_name)
      case action_name
      when "wallet"
        return Wallet.new(
          {name: "wallet", desc: "create, encrypt or decrypt your wallet"},
          next_parents,
        ).run
      when "blockchain"
        return Blockchain.new(
          {name: "blockchain", desc: "get a whole blockchain or each block"},
          next_parents,
        ).run
      when "transaction"
        return Transaction.new(
          {name: "transaction", desc: "get or create transactions"},
          next_parents,
        ).run
      when "config"
        return Config.new(
          {name: "config", desc: "save default configuration used by sushi, sushid and sushim"},
          next_parents,
        ).run
      end

      specify_subaction!
    end
  end
end

include ::Sushi::Interface
include ::Sushi::Core::Keys

::Sushi::Interface::Sushi::Root.new(
  {name: "sushi", desc: "sushi's command line client"}, [] of SushiAction
).run
