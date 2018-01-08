require "../cli"
require "./garnetd/*"

module ::Garnet::Interface::GarnetD
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

include ::Garnet::Interface

::Garnet::Interface::GarnetD::Root.new(
  { name: "garnetd", desc: "Garnet's node" }, [] of GarnetAction
).run
