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

      # launch other nodes
      # the connection order is not the order (it's random)
      node(4001, false, 4000, 1)
      node(4002, false, 4000, 2)
      node(4003, true, 4000, 3)
      node(4004, false, 4001, 4)
      node(4005, false, 4002, 5)
    end

    def kill_nodes
      `pkill -f sushid`
    end

    def start_mining
      mining(4000, 1)
    end

    def stop_mining
      `pkill -f sushim`
    end

    def run!
      pre_build
      launch_nodes

      sleep 1
      start_mining
    end

    def fin
      stop_mining

      sleep 1

      STDERR.puts "start assertion"
      STDERR.puts "checking latest blocks..."

      latest_block_index = NODE_PORTS.map { |port| STDERR.puts "checking #{port}"; blockchain_size(port) }.min

      STDERR.puts "size: #{latest_block_index}"

      kill_nodes
    end

    include Utils
  end
end
