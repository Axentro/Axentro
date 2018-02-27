require "../cli"
require "./sushi/*"

module ::Sushi::Interface::Sushi
  class Root < CLI
    def sub_actions
      [
        {
          name: "wallet",
          desc: "create, encrypt or decrypt your wallet (wt for short)",
        },
        {
          name: "blockchain",
          desc: "get a whole blockchain or each block (bc for short)",
        },
        {
          name: "transaction",
          desc: "get or create transactions (tx for short)",
        },
        {
          name: "scars",
          desc: "SushiCon Address Resolution System (SCARS), buy/sell a readable domain for your address (sc for short)",
        },
        {
          name: "config",
          desc: "save default configuration used by sushi, sushid and sushim (cg for short)",
        },
      ]
    end

    def option_parser
      nil
    end

    def run_impl(action_name)
      case action_name
      when "wallet", "wt"
        return Wallet.new(
          {name: "wallet", desc: "create, encrypt or decrypt your wallet"},
          next_parents,
        ).run
      when "blockchain", "bc"
        return Blockchain.new(
          {name: "blockchain", desc: "get a whole blockchain or each block"},
          next_parents,
        ).run
      when "transaction", "tx"
        return Transaction.new(
          {name: "transaction", desc: "get or create transactions"},
          next_parents,
         ).run
      when "scars", "sc"
        return Scars.new(
                 {name: "scars", desc: "SushiCon Address Resolution System (SCARS), buy/sell a readable domain for your address"},
                 next_parents,
               ).run
      when "config", "cg"
        return Config.new(
          {name: "config", desc: "save default configuration used by sushi, sushid and sushim"},
          next_parents,
        ).run
      end

      specify_sub_action!(action_name)
    end
  end
end

include ::Sushi::Interface
include ::Sushi::Core::Keys

::Sushi::Interface::Sushi::Root.new(
  {name: "sushi", desc: "sushi's command line client"}, [] of SushiAction
).run
