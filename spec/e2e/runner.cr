require "random"
require "./utils"

module ::E2E

  class Runner
    @node_ports : Array(Int32)

    def initialize(@num_nodes : Int32, @num_miners : Int32)
      raise "@num_nodes has to be grater than 0" if @num_nodes < 0
      raise "@num_nodes of E2E::Runner has to be less than 6" if @num_nodes > 6
      raise "@num_miners of E2E::Runner has to be less than 6" if @num_miners > 6

      @node_ports = (4000..4000+(@num_nodes-1)).to_a
    end

    def pre_build
      STDERR.puts `shards build`
    end

    def launch_nodes
      # genesis node
      node(@node_ports[0], false, nil, 0)

      node_ports_public = [@node_ports[0]]

      sleep 1

      @node_ports[1..-1].each_with_index do |node_port, idx|
        is_private = Random.rand(10) < 2
        connecting_port = node_ports_public.sample

        node(node_port, is_private, connecting_port, idx+1)
        node_ports_public.push(node_port) unless is_private
        sleep 1
      end
    end

    def kill_nodes
      `pkill -f sushid`
    end

    def launch_miners
      @num_miners.times do |i|
        mining(@node_ports.sample, Random.rand(@num_miners))
      end
    end

    def kill_miners
      `pkill -f sushim`
    end

    def num_processes_node : Int32
      STDERR.puts `ps aux | grep sushid | grep -v grep` # debug
      `ps aux | grep sushid | grep -v grep`.split("\n").size / 2
    end

    def assertion!
      raise "# of node processes has to be #{@num_nodes} (#{num_processes_node})" if @num_nodes != num_processes_node

      latest_block_index = @node_ports.map { |port|
        size = blockchain_size(port)
        STDERR.puts "#{port} <- #{size}"
        size-1
      }.min

      return STDERR.puts yellow("mining is not enough") if latest_block_index < 2

      checking_block_index = latest_block_index - 2

      block_json = block(@node_ports[0], checking_block_index)

      @node_ports[1..-1].each do |node_port|
        _block_json = block(node_port, checking_block_index)
        raise "Difference block #{block_json} vs #{_block_json}" if block_json != _block_json
      end
    end

    def run!
      kill_nodes
      kill_miners

      pre_build

      launch_nodes
      sleep 1

      launch_miners
      sleep 600

      kill_miners
      sleep 1

      assertion!
    ensure
      kill_nodes
    end

    include Utils
  end
end
