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
require "file_utils"
require "./utils"
require "./client"

module ::E2E
  ALL_PUBLIC  = 0
  ALL_PRIVATE = 1
  ONE_PRIVATE = 2

  CONFIRMATION = 3

  class Runner
    @client : Client
    @db_name : String

    @node_ports : Array(Int32)
    @node_ports_public : Array(Int32) = [] of Int32

    getter exit_code : Int32 = 0

    def initialize(@mode : Int32, @num_nodes : Int32, @num_miners : Int32, @time : Int32)
      @node_ports = (4000..4000 + (@num_nodes - 1)).to_a

      @client = Client.new(@node_ports, @num_miners)
      @db_name = Random.new.hex
    end

    def create_wallets
      [@num_nodes, @num_miners].max.times do |idx|
        create_wallet(idx)
      end
    end

    def launch_node(node_port, is_private, connecting_port, idx, db = nil)
      node(node_port, is_private, connecting_port, idx, db)
      @node_ports_public.push(node_port) unless is_private
    end

    def launch_first_node
      launch_node(@node_ports[0], false, nil, 0, @db_name)
    end

    def launch_nodes
      step launch_first_node, 5, "launch first node"

      @node_ports[1..-1].each_with_index do |node_port, idx|
        is_private = case @mode
                     when E2E::ALL_PUBLIC
                       false
                     when E2E::ALL_PRIVATE
                       true
                     when E2E::ONE_PRIVATE
                       idx == 0
                     else
                       false
                     end

        connecting_port = @node_ports_public.sample

        step launch_node(node_port, is_private, connecting_port, idx + 1), 5,
          "launch node on port #{node_port} connect to #{connecting_port} #{is_private ? "(private)" : "(public)"}"
      end
    end

    def kill_nodes
      `pkill -f sushid`
    end

    def launch_miners
      @num_miners.times do |i|
        port = @node_ports.sample
        step mining(port, Random.rand(@num_miners)), 1, "launch miner for #{port}"
      end
    end

    def kill_miners
      `pkill -f sushim`
    end

    def launch_client
      @client.launch
    end

    def kill_client
      @client.kill
    end

    def block_sizes : Array(NamedTuple(port: Int32, size: Int32))
      @node_ports.map { |port| {port: port, size: blockchain_size(port)} }
    end

    def latest_block_index : Int32
      block_sizes.min_by { |port_size| port_size[:size] }[:size] - 1
    end

    def latest_confirmed_block_index : Int32
      if latest_block_index < CONFIRMATION - 1
        return 1 if latest_block_index > 1
        return 0
      end
      latest_block_index - (CONFIRMATION - 1)
    end

    def verify_at_least_mining_one_block
      STDERR.puts
      STDERR.puts "verifying: #{green("at least mining one block")}"

      block_sizes.each do |port_size|
        raise "node #{port_size[:port]} has no mined block" if port_size[:size] < 3
        STDERR.print "."
      end

      STDERR.puts
      STDERR.puts light_green("-> PASSED!")
    end

    def verify_latest_confirmed_block
      _latest_confirmed_block_index = latest_confirmed_block_index

      STDERR.puts
      STDERR.puts "verifying: #{green("latest confirmed block")} #{green(_latest_confirmed_block_index)}..."

      block_json = block(@node_ports[0], _latest_confirmed_block_index)

      @node_ports[1..-1].each do |node_port|
        _block_json = block(node_port, _latest_confirmed_block_index)
        raise "difference block #{block_json} vs #{_block_json}" if block_json != _block_json
        STDERR.print "."
      end

      STDERR.puts
      STDERR.puts light_green("-> PASSED!")
    end

    def verify_blockchain_sizes_are_almost_same
      STDERR.puts
      STDERR.puts "verifying: #{green("latest blockchain sizes")}..."

      min_size = blockchain_size(@node_ports[0])

      @node_ports[1..-1].each do |node_port|
        size = blockchain_size(node_port)

        raise "blockchain size is completely different. (#{min_size} vs #{size})" if (size - min_size).abs > 2
        STDERR.print "."

        min_size = size if size < min_size
      end

      STDERR.puts
      STDERR.puts light_green("-> PASSED!")
    end

    def verify_all_addresses_have_non_negative_amount
      STDERR.puts
      STDERR.puts "verifying: #{green("all addresses have non-negative amount")}"

      @node_ports.each do |node_port|
        @num_miners.times do |num|
          a = amount(node_port, num, CONFIRMATION)
          raise "amount of #{num} is #{a} on #{node_port} (#{CONFIRMATION})" if a < 0
          STDERR.print "."

          a = amount(node_port, num)
          raise "amount of #{num} is #{a} on #{node_port}" if a < 0
          STDERR.print "."
        end
      end

      STDERR.puts
      STDERR.puts light_green("-> PASSED!")
    end

    def verify_blockchain_can_be_restored_from_database
      STDERR.puts
      STDERR.puts "verifying: #{green("blockchain can be restored from database")}"

      size0 = blockchain_size(4000)

      step create_wallet(100), 0, ""
      step launch_node(5000, true, nil, 100, @db_name), 10, ""

      size1 = blockchain_size(5000)

      raise "restoring blockchain failed (size : #{size0}, db: #{size1})" unless size0 == size1

      STDERR.print "."
      STDERR.puts
      STDERR.puts light_green("-> PASSED!")
    end

    def benchmark_result
      STDERR.puts
      STDERR.puts "**************** #{light_yellow("benchmark")} ****************"
      STDERR.puts "- transactions  : #{@client.num_transactions}"
      STDERR.puts "- duration      : #{@client.duration} [sec]"
      STDERR.puts "- result        : #{light_green(@client.num_transactions/@client.duration)} [transactions/sec]"
      STDERR.puts "- # of nodes    : #{@num_nodes}"
      STDERR.puts "- # of miners   : #{@num_miners}"
      STDERR.puts "**************** #{light_yellow("status")} ****************"

      @node_ports.each do |port|
        size = blockchain_size(port)
        STDERR.puts "> blocks on port #{port} (size: #{size})"

        size.times do |i|
          unless block = block(port, i)
            STDERR.puts "%2d --- %s" % [i, "failed to get block at #{i} on #{port}"]
            next
          end

          STDERR.puts "%2d --- %s" % [i, block["prev_hash"].as_s]
        end
      end
    end

    def assertion!
      verify_at_least_mining_one_block
      verify_latest_confirmed_block
      verify_blockchain_sizes_are_almost_same
      verify_all_addresses_have_non_negative_amount
      verify_blockchain_can_be_restored_from_database
    end

    def clean_db
      Dir.glob(File.expand_path("../db/*.db", __FILE__)) do |db|
        FileUtils.rm_rf db
      end
    end

    def clean_wallets
      Dir.glob(File.expand_path("../wallets/*.json", __FILE__)) do |wallet|
        FileUtils.rm_rf wallet
      end
    end

    def clean_logs
      Dir.glob(File.expand_path("../logs/*.log", __FILE__)) do |log|
        FileUtils.rm_rf log
      end
    end

    def running
    end

    macro step(func, interval, desc)
      STDERR.puts "__ step __ (sleep: #{{{interval.id}}}) " + {{desc}} if {{desc}}.size > 0

      {{func.id}}
      sleep {{interval.id}}
    end

    def run!
      mode_str = case @mode
                 when E2E::ALL_PUBLIC
                   "ALL_PUBLIC"
                 when E2E::ALL_PRIVATE
                   "ALL_RPIVATE"
                 when E2E::ONE_PRIVATE
                   "ONE_PRIVATE"
                 else
                   "UNKNOWN"
                 end

      STDERR.puts "start E2E tests with #{light_green(mode_str)} mode"

      step kill_nodes, 0, "kill existing nodes"
      step kill_miners, 0, "kill existing miners"
      step clean_logs, 0, "clean logs"
      step create_wallets, 0, "create wallets"
      step launch_nodes, 1, "launch nodes"
      step launch_miners, 1, "launch miners"
      step launch_client, 1, "launch client"

      running_steps = @time/300
      running_steps.times do |i|
        step running, 300, "running..."
      end

      step running, @time % 300, "running..."

      step kill_client, 10, "kill client"
      step kill_miners, 10, "kill miners"
      step assertion!, 0, "start assertion"
    rescue e : Exception
      STDERR.puts "-> FAILED!"
      STDERR.puts "   the reason: #{e.message}"

      @exit_code = -1
    ensure
      step benchmark_result, 0, "show benchmark result"
      step kill_nodes, 0, "kill nodes"
      step clean_db, 2, "clean database"
      step clean_wallets, 2, "clean wallets"
    end

    include Utils
  end
end
