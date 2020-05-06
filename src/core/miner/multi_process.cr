module ::Sushi::Core::MultiProcess
  abstract class Worker
    abstract def task(message : String)

    getter terminate : Channel(Nil)
    getter name : String

    def self.create(number_of_workers : Int32) : Array(Worker)
      workers = [] of Worker
   
      (1..number_of_workers).each do |n|
        inbound = Channel(String).new
        outbound = Channel(String).new
        terminate = Channel(Nil).new
        worker = new(inbound, outbound, terminate, "worker_#{n}")
        worker.run
        workers << worker
      end
      workers
    end

    @message_pool = [] of String

    def initialize(@inbound : Channel(String), @outbound : Channel(String), @terminate : Channel(Nil), @name : String)
    end

    def run
      spawn(name: "run_fiber") do
        loop do
          break if @terminate.closed?
          next unless message = @inbound.receive?

          task(message)
        end
      end
      wait_fiber
    end

    def wait_fiber
      spawn(name: "wait_fiber") do
       loop do
          break if @terminate.closed?
          # sleep 0.01
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
      return nil unless message = @outbound.receive?

      message
    end

    def kill
      @terminate.close
      @message_pool.clear
      @inbound.close
      @outbound.close
    end
  end
end
