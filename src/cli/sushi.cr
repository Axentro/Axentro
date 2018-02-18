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
      ]
    end

    def option_parser
      nil
    end

    def run_impl(action_name)
      case action_name
      when "wallet"
        Wallet.new(
          {name: "wallet", desc: "create, encrypt or decrypt your wallet"},
          next_parents,
        ).run
      when "blockchain"
        Blockchain.new(
          {name: "blockchain", desc: "get a whole blockchain or each block"},
          next_parents,
        ).run
      when "transaction"
        Transaction.new(
          {name: "transaction", desc: "get or create transactions"},
          next_parents,
        ).run
      end
    end
  end
end

include ::Sushi::Interface
include ::Sushi::Core::Keys

::Sushi::Interface::Sushi::Root.new(
  {name: "sushi", desc: "sushi's command line client"}, [] of SushiAction
).run
