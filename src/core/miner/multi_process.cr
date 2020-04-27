module ::Sushi::Core::MultiProcess
  abstract class Worker
    abstract def task(message : String)

    def self.create(number_of_workers : Int32) : Array(Worker)
      workers = [] of Worker
      inbound = Channel(String).new
      outbound = Channel(String).new

      number_of_workers.times do |_|
        worker = new(inbound, outbound)
        worker.run
        workers << worker
      end
      workers
    end

    @message_pool = [] of String

    def initialize(@inbound : Channel(String), @outbound : Channel(String))
    end

    def run
      spawn do
        loop do
          next unless message = @inbound.receive

          task(message)
        end
      end
      wait_fiber
    end

    def wait_fiber
      spawn do
       loop do
          sleep 0.01
          next unless message = @message_pool.shift?
          @inbound.send(message)
        end
      end
    end

    def exec(message : String? = nil)
      @message_pool << message
    end

    def response(message : String)
      @outbound.send(message)
    end

    def receive : String?
      return nil unless message = @outbound.receive

      message
    end

    def kill
     # no idea how to stop the Fiber
    end
  end
end
