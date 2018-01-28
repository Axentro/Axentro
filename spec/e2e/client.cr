require "random"
require "./utils"

module ::E2E
  class Client
    @transaction_ids = [] of String
    @alive : Bool

    def initialize(@node_ports : Array(Int32), @num_miners : Int32)
      @alive = true
    end

    def create_transaction
      sender = Random.rand(@num_miners)
      recipient = Random.rand(@num_miners)

      if transaction_id = create(@node_ports.sample, sender, recipient)
        @transaction_ids << transaction_id
      end
    end

    def launch
      spawn do
        loop do
          break if !@alive
          create_transaction

          sleep 0.01
        rescue e : Exception
          STDERR.puts e
        end
      end
    end

    def kill
      @alive = false
    end

    include Utils
  end
end
