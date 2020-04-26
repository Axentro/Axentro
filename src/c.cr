class Worker
  def initialize(@channel : Channel(String))
  end

  def execute(instruction)
    spawn { @channel.send("#{Time.utc.second}_#{instruction}") }
  end
end

nonce_channel = Channel(String).new

worker1 = Worker.new(nonce_channel)
worker2 = Worker.new(nonce_channel)

worker1.execute("1")
worker2.execute("2")

loop do
  p nonce_channel.receive
end

# sleep 5
