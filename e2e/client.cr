# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
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
    @@no_transactions : Bool = false

    alias ClientWork = NamedTuple(call: Int32, content: String)

    struct Initialize
      include JSON::Serializable
      property node_ports : Array(Int32)
      property num_miners : Int32
      property num_tps : Int32
      property pct_fast_txns : Int32
    end

    struct Result
      include JSON::Serializable
      property num_transactions : Int32
      property duration : Float64
    end

    def self.client
      @@client.not_nil!
    end

    def self.initialize(node_ports : Array(Int32), num_miners : Int32, no_transactions : Bool, num_tps : Int32, pct_fast_txns : Int32)
      @@client = Client.create(1)[0]
      @@no_transactions = no_transactions

      puts "Transactions Per Second goal: #{num_tps}"
      puts "(as many as possible)" if num_tps == 0

      puts "Fast transaction percentage: #{pct_fast_txns}"

      request = {call: 0, content: {node_ports: node_ports, num_miners: num_miners, num_tps: num_tps, pct_fast_txns: pct_fast_txns}.to_json}.to_json
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
        @num_tps = initialize.num_tps
        @pct_fast_txns = initialize.pct_fast_txns
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
    @num_tps : Int32 = 0

    @pct_fast_txns : Int32 = 1

    def create_transaction(doing_fast_transaction : Bool)
      sender = Random.rand(@num_miners)
      recipient = Random.rand(@num_miners)

      if transaction_id = create(@node_ports.sample, sender, recipient, doing_fast_transaction)
        @launch_time ||= Time.utc
        @transaction_ids << transaction_id
      end
    end

    def launch
      if @@no_transactions
        @launch_time ||= Time.utc
        nil
      else
        spawn do
          transaction_counter = 0_i64
          while @alive
            begin
              transaction_hundred_count = transaction_counter % 100_i64
              doing_fast_transactions = false
              if @pct_fast_txns > 0
                doing_fast_transactions = transaction_hundred_count < @pct_fast_txns
              end
              create_transaction(doing_fast_transactions)
              if @num_tps > 0
                sleepy_time = 1000 / @num_tps
                sleep sleepy_time.milliseconds
              end
              transaction_counter += 1_i64
            rescue e : Exception
              STDERR.puts red(e.message.not_nil!)
            end
          end
        end
      end
    end

    def kill
      @kill_time = Time.utc
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
