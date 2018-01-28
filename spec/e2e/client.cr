require "random"
require "./utils"

module ::E2E
  class Client
    @transaction_ids = [] of String

    def initialize(@node_ports : Array(Int32), @num_miners : Int32)
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
          create_transaction
          sleep 1
        rescue e : Exception
          STDERR.puts e
        end
      end
    end

    def assertion!
      @transaction_ids.each do |id|
        port = @node_ports.sample
        transaction(port, id)
      end
    end

    include Utils
  end
end
