require "random"
require "./utils"

module ::E2E
  class Client

    def launch
      spawn do
        loop do
          sleep 10
          STDERR.puts "In client"

          create(0, 1)
        rescue e : Exception
          STDERR.puts e
        end
      end
    end

    include Utils
  end
end
