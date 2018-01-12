require "../cli"
require "./sushid/*"

module ::Sushi::Interface::SushiD
  class Root < CLI
    def sub_actions
      [
        {
          name: "start",
          desc: "Start a node",
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

::Sushi::Interface::SushiD::Root.new(
  { name: "sushid", desc: "Sushi's node" }, [] of SushiAction
).run
