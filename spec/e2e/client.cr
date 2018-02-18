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
      @launch_time = Time.now

      spawn do
        while @alive
          begin
            create_transaction
          rescue e : Exception
            STDERR.puts red(e.message.not_nil!)
          end
        end
      end
    end

    def kill
      @kill_time = Time.now
      @alive = false

      `pkill -f sushi`
    end

    def num_transactions : Int32
      @transaction_ids.size
    end

    def duration : Float64
      raise "@launch_time or @kill_time is nil!" if @launch_time.nil? || @kill_time.nil?
      (@kill_time.not_nil! - @launch_time.not_nil!).total_seconds
    end

    include Utils
  end
end
