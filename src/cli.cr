require "option_parser"
require "file_utils"
require "colorize"
require "uri"

require "./core"
require "./cli/helps"
require "./cli/modules"

module ::Sushi::Interface
  alias SushiAction = NamedTuple(name: String, desc: String)

  abstract class CLI
    def initialize(
      @action : SushiAction,
      @parents : Array(SushiAction),
      @has_default_action : Bool = false
    )
    end

    def puts_help(message = "Showing help message.", exit_code = -1)
      available_sub_actions =
        sub_actions.map { |a| " - #{light_green("%-20s" % a[:name])} | #{"%-40s" % a[:desc]}" }.join("\n")
      available_sub_actions = "Nothing" if available_sub_actions == ""

      message_size = message.split("\n").max_by { |m| m.size }.size
      messages = message.split("\n").map { |m| white_bg(black(" %-#{message_size}s " % m)) }

      puts "\n" +
           "#{light_magenta("Sushi")} #{@action[:desc]}\n\n" +
           "#{white_bg(black(" " + "-" * message_size + " "))}\n" +
           messages.join("\n") + "\n" +
           "#{white_bg(black(" " + "-" * message_size + " "))}\n\n" +
           "This is a help message for\n" +
           "> #{light_cyan(command_line)}\n" +
           "\n" +
           "Available sub actions\n" +
           available_sub_actions +
           "\n\n" +
           "Available options\n" +
           (option_parser.nil? ? "Nothing" : option_parser.to_s) +
           "\n\n"

      exit exit_code
    end

    def command_line
      return @action[:name] if @parents.size == 0
      @parents.map { |a| a[:name] }.join(" ") + " " + @action[:name]
    end

    def next_parents : Array(SushiAction)
      @parents.concat([@action])
    end

    def sub_action_names : Array(String)
      sub_actions.map { |a| a[:name] }
    end

    def run
      if ARGV.size > 0 && ARGV[0] == "help"
        puts_help
      end

      if ARGV.size > 0 &&
         !ARGV[0].starts_with?('-') &&
         !sub_action_names.includes?(ARGV[0])
        puts_help("Invalid action '#{ARGV[0]}' for '#{command_line}'")
        exit -1
      end

      if ARGV.size == 0 && !@has_default_action
        puts_help
        exit -1
      end

      action_name = ARGV.size > 0 && !@has_default_action ? ARGV.shift : nil

      if parser = option_parser
        parser.parse!
      end

      run_impl(action_name)
    rescue e : Exception
      if error_message = e.message
        puts_error(e.message)
      else
        puts_error(e.backtrace.join("\n"))
      end
    end

    def option_error(option_name : String, parser : OptionParser)
      puts_error("Please specify #{option_name}")
      puts ""
      puts parser.to_s
      exit -1
    end

    def rpc(node, payload : String) : String
      res = HTTP::Client.post("#{node}/rpc", HTTP::Headers.new, payload)
      verify_response!(res)
    end

    def verify_response!(res) : String
      unless res.status_code == 200
        puts_error "Failed to call an API."
        puts_error res.body
        exit -1
      end

      unless body = res.body
        puts_error "Returned body is empty"
        exit -1
      end

      body
    end

    abstract def sub_actions : Array(SushiAction)
    abstract def option_parser : OptionParser?
    abstract def run_impl(action_name : String?) : OptionParser?

    include Helps
    include Logger
    include Common::Num
  end
end
