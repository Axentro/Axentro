module ::Sushi::Core
  abstract class Job
    abstract def task(message : MinerWork, terminate : Channel(Nil)) : MinerNonce
  end

  class JobRunner
    @terminate : Channel(Nil) = JobRunner.terminate_channel
    @results : Array(Channel(MinerNonce)) = [] of Channel(MinerNonce)

    def initialize(@number_of_fibers : Int32); end

    def self.terminate_channel
        Channel(Nil).new
    end

    def run(job : Job, message : MinerWork)
      @results = (1..@number_of_fibers).map do |n|
        result = Channel(MinerNonce).new
        spawn(name: "worker_#{n}") do
          loop do
            break if @terminate.closed?
            debug "inside worker: #{Fiber.current.name}"
            miner_nonce = job.task(message, @terminate)

            debug "NONCE FOUND: by #{Fiber.current.name}"
            result.send(miner_nonce.not_nil!)
          end
        end
        result
      end
    end

    def receive(func)
      loop do
        break if @terminate.closed?
        miner_nonce = Channel.receive_first(@results)
        func.call(miner_nonce)
      end
    end

    include Logger
  end
end
