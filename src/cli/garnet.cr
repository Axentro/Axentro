require "../cli"
require "./garnet/*"

module ::Garnet::Interface::Garnet
  class Root < CLI
    def sub_actions
      [
        {
          name: "wallet",
          desc: "Create or verify your wallet.json.",
        },
        {
          name: "app",
          desc: "Send Garnet coins, upload or download files.",
        },
      ]
    end

    def option_parser
      nil
    end

    def run_impl(action_name)
      case action_name
      when "wallet"
        wallet = Wallet.new(sub_actions[0], next_parents)
        wallet.run
      when "app"
        app = App.new(sub_actions[1], next_parents)
        app.run
      end
    end
  end
end

include ::Garnet::Interface

::Garnet::Interface::Garnet::Root.new(
  { name: "garnet", desc: "Garnet's command line client" }, [] of GarnetAction
).run
