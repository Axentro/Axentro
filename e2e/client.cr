# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "random"
require "./utils"

module ::E2E
  class Client < Tokoroten::Worker
    @@client : Tokoroten::Worker? = nil

    alias ClientWork = NamedTuple(call: Int32, content: String)

    struct Initialize
      JSON.mapping({node_ports: Array(Int32), num_miners: Int32})
    end

    struct Result
      JSON.mapping({num_transactions: Int32, duration: Float64})
    end

    def self.client
      @@client.not_nil!
    end

    def self.initialize(node_ports : Array(Int32), num_miners : Int32)
      @@client = Client.create(1)[0]

      request = {call: 0, content: {node_ports: node_ports, num_miners: num_miners}.to_json}.to_json
      client.exec(request)
    end

    def self.launch
      request = {call: 1, content: ""}.to_json
      client.exec(request)
    end

    def self.finish
      request = {call: 2, content: ""}.to_json
      client.exec(request)
    end

    def task(message : String)
      work = ClientWork.from_json(message)

      case work[:call]
      when 0 # initialize
        initialize = Initialize.from_json(work[:content])

        @node_ports = initialize.node_ports
        @num_miners = initialize.num_miners
      when 1 # launch
        launch
      when 2 # finish
        kill

        response({num_transactions: num_transactions, duration: duration}.to_json)
      end
    end

    def self.receive
      client.receive
    end

    @transaction_ids = [] of String

    @alive : Bool = true

    @node_ports : Array(Int32) = [] of Int32
    @num_miners : Int32 = 0

    def create_transaction
      sender = Random.rand(@num_miners)
      recipient = Random.rand(@num_miners)

      # todo
      # if transaction_id = create(@node_ports.sample, sender, recipient)
      if transaction_id = create(4000, sender, recipient)
        @launch_time ||= Time.now
        @transaction_ids << transaction_id
        puts "total: #{@transaction_ids.size}" # todo
      end
    end

    def launch
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
