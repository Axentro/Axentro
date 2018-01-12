require "../cli"
require "./sushim/*"

module ::Sushi::Interface::SushiM
  class Root < CLI
    def sub_actions
      [
        {
          name: "start",
          desc: "Start a mining process",
        },
      ]
    end

    def option_parser
      nil
    end

    def run_impl(action_name)
      case action_name
      when "start"
        start = Start.new(sub_actions[0], next_parents, true)
        start.run
      end
    end
  end
end

include ::Sushi::Interface

::Sushi::Interface::SushiM::Root.new(
  { name: "sushim", desc: "Sushi's mining process" }, [] of SushiAction
).run
