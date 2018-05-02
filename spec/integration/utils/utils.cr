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

module ::Utils::Integration
  def bin
    File.expand_path("../../../../bin", __FILE__)
  end

  def system_sushi(args : Array(String)) : Bool
    system("#{bin}/sushi #{args.join(" ")} 1>&2 > /dev/null")
  end

  def exec_sushi(args : Array(String)) : String
    `#{bin}/sushi #{args.join(" ")}`
  end

  def exec_sushim(args : Array(String)) : String
    `#{bin}/sushim #{args.join(" ")}`
  end

  def exec_sushid(args : Array(String)) : String
    `SET_DIFFICULTY=1 #{bin}/sushid #{args.join(" ")}`
  end

  def wallet(num : Int32) : String
    File.expand_path("../../wallets/testnet-#{num}.json", __FILE__)
  end

  def node : String
    "http://127.0.0.1:3100"
  end

  def start_node
    spawn exec_sushid(["-u", "http://127.0.0.1:3100", "-p", "3100", "-w", wallet(0), "--private", "--testnet"])
  end

  def start_mining
    spawn exec_sushim(["-n", "http://127.0.0.1:3100", "-w", wallet(1), "--testnet"])
  end

  def kill_all
    kill_node
    kill_miner
  end

  def kill_node
    `pkill -f sushid`
  end

  def kill_miner
    `pkill -f sushim`
  end

  def blockchain_size : Int32
    JSON.parse(exec_sushi(["bc", "size", "-n", node, "--json"]))["size"].as_i
  end

  def wait_mining(nblock : Int32)
    kill_miner

    base_size = blockchain_size

    start_mining

    loop do
      current_size = blockchain_size
      break if current_size >= base_size + nblock

      sleep 0.1
    end

    kill_miner
  end
end
