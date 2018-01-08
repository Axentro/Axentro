require "../cli"
require "./garnetm/*"

module ::Garnet::Interface::GarnetM
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

include ::Garnet::Interface

::Garnet::Interface::GarnetM::Root.new(
  { name: "garnetm", desc: "Garnet's mining process" }, [] of GarnetAction
).run
