require "random"
require "./utils"

module ::Integration

  class Runner
    NODE_PORTS = (4000..4005).to_a

    def initialize
    end

    def pre_build
      STDERR.puts `shards build`
    end

    def launch_nodes
      # genesis node
      node(4000, false, nil, 0)

      sleep 1

      public_node_ports = [4000]

      # launch other nodes
      # the connection order is not the order (it's random)
      NODE_PORTS[1..-1].each_with_index do |node_port, idx|
        is_private = Random.rand(10) < 3
        connecting_port = public_node_ports[Random.rand(public_node_ports.size)]

        node(node_port, is_private, connecting_port, idx+1)
      end
    end

    def kill_nodes
      `pkill -f sushid`
    end

    def start_mining
      NODE_PORTS.each do |node_port|
        mining(node_port, Random.rand(NODE_PORTS.size))
      end
    end

    def stop_mining
      `pkill -f sushim`
    end

    def assertion : Bool
      STDERR.puts light_green("start assertion")
      STDERR.puts light_green("checking latest blocks...")

      latest_block_index = NODE_PORTS.map { |port|
        size = blockchain_size(port)
        STDERR.puts "#{port} <- #{size}"
        size
      }.min

      STDERR.puts "size: #{latest_block_index}"

      true
    end

    def run! : Bool
      pre_build

      launch_nodes

      sleep 1

      start_mining

      sleep 10

      stop_mining

      sleep 1

      res = assertion

      sleep 1

      kill_nodes

      res
    end

    include Utils
  end
end
