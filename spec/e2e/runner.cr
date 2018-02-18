require "random"
require "file_utils"
require "./utils"
require "./client"

module ::E2E
  class Runner
    @client : Client
    @db_name : String

    @node_ports : Array(Int32)

    def initialize(@num_nodes : Int32, @num_miners : Int32)
      raise "@num_nodes has to be grater than 0" if @num_nodes < 0
      raise "@num_nodes of E2E::Runner has to be less than 5" if @num_nodes > 5
      raise "@num_miners of E2E::Runner has to be less than 6" if @num_miners > 6

      @node_ports = (4000..4000 + (@num_nodes - 1)).to_a

      @client = Client.new(@node_ports, @num_miners)
      @db_name = Random.new.hex
    end

    def pre_build
      raise "Build failed" unless system("shards build")
    end

    def launch_nodes
      # genesis node
      node(@node_ports[0], false, nil, 0, @db_name)

      node_ports_public = [@node_ports[0]]

      sleep 1

      @node_ports[1..-1].each_with_index do |node_port, idx|
        is_private = Random.rand(10) < 2
        connecting_port = node_ports_public.sample

        node(node_port, is_private, connecting_port, idx + 1)
        node_ports_public.push(node_port) unless is_private
        sleep 1
      end
    end

    def kill_nodes
      `pkill -f sushid`
      STDERR.puts `ps aux | grep sushi`
    end

    def launch_miners
      @num_miners.times do |i|
        mining(@node_ports.sample, Random.rand(@num_miners))
      end
    end

    def kill_miners
      `pkill -f sushim`
      STDERR.puts `ps aux | grep sushi`
    end

    def launch_client
      @client.launch
    end

    def kill_client
      @client.kill
    end

    def latest_block_index : Int32
      latest_block_index = @node_ports.map { |port|
        size = blockchain_size(port)
        size - 1
      }.max
    end

    def latest_confirmed_block_index : Int32
      return 0 if latest_block_index < ::Sushi::Core::UTXO::CONFIRMATION - 1
      latest_block_index - (::Sushi::Core::UTXO::CONFIRMATION - 1)
    end

    def verify_latest_confirmed_block
      STDERR.puts
      STDERR.puts "Verifying: #{green("latest confirmed block")} #{green(latest_confirmed_block_index)}..."

      block_json = block(@node_ports[0], latest_confirmed_block_index)

      @node_ports[1..-1].each do |node_port|
        _block_json = block(node_port, latest_confirmed_block_index)
        raise "Difference block #{block_json} vs #{_block_json}" if block_json != _block_json
        STDERR.print "."
      end

      STDERR.puts
      STDERR.puts light_green("-> PASSED!")
    end

    def verify_all_addresses_have_non_negative_amount
      STDERR.puts
      STDERR.puts "Verifying: #{green("all addresses have non-negative amount")}"

      @node_ports.each do |node_port|
        @num_miners.times do |num|
          a = amount(node_port, num)
          raise "Amount of #{num} is #{a} on #{node_port}" if a < 0
          STDERR.print "."

          a = amount(node_port, num, true)
          raise "Amount of #{num} is #{a} on #{node_port} (unconfirmed)" if a < 0
          STDERR.print "."
        end
      end

      STDERR.puts
      STDERR.puts light_green("-> PASSED!")
    end

    def verify_blockchain_can_be_restored_from_database
      STDERR.puts
      STDERR.puts "Verifying: #{green("blockchain can be restored from database")}"

      size0 = blockchain_size(4000)

      node(5000, true, nil, 5, @db_name, false)

      sleep 60

      size1 = blockchain_size(5000)

      raise "Restoring blockchain failed (size : #{size0}, db: #{size1})" unless size0 == size1

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
      STDERR.puts "- nodes         : #{@num_nodes}"
      STDERR.puts "- miners        : #{@num_miners}"
    end

    def assertion!
      verify_latest_confirmed_block
      verify_all_addresses_have_non_negative_amount
      verify_blockchain_can_be_restored_from_database

      benchmark_result
    end

    def clean_db
      FileUtils.rm_rf(File.expand_path("../db/#{@db_name}.db", __FILE__))
    end

    def run!
      kill_nodes
      kill_miners

      pre_build

      launch_nodes

      sleep 1

      launch_miners

      sleep 1

      launch_client

      sleep 300

      kill_client

      sleep 1

      kill_miners

      sleep 1

      assertion!
    ensure
      kill_nodes

      clean_db
    end

    include Utils
  end
end
