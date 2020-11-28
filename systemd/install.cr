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

require "option_parser"

class SystemInstall
  def exec
    install = false
    run = false
    run_cli = false
    environment = "testnet"
    option_parse = OptionParser.parse do |parser|
      parser.banner = "Usage: command [args]"

      parser.on("install", "install systemd & rsyslog for axen") do
        install = true
      end

      parser.on("run", "run the axen systemd") do
        run = true
        parser.on("-c", "--cli", "Run in cli") { run_cli = true }
      end

      parser.on("--testnet", "use testnet env") { environment = "testnet" }
      parser.on("--mainnet", "use mainnet env") { environment = "mainnet" }
      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit
      end
    end

    option_parse.parse

    if install
      install_axen(environment)
    elsif run
      run_axen(environment, run_cli)
    end
  end

  def install_axen(env : String)
    puts "installing axen for env: #{env} to systemd"
    conf = File.read_lines(File.expand_path("./systemd/axen.service")).join("\n")
    conf = conf.gsub("<environment>", env)
    file_name = "axen-#{env}.service"
    File.open(file_name, "w") { |f| f.puts conf }
    puts `sudo mv #{file_name} /etc/systemd/system/axen.service`
    puts "installing rsyslog"
    puts `sudo cp #{File.expand_path("./systemd/49-axentro.conf")} /etc/rsyslog.d/`
    puts "reloading systemd daemon"
    puts `sudo systemctl daemon-reload`
    puts "enabling axen"
    puts `sudo systemctl enable axen.service`
    puts "restarting rsyslog"
    puts `sudo systemctl restart rsyslog`
  end

  def run_axen(env : String, run_cli : Bool)
    if run_cli
      puts "running axen in the cli for env: #{env}"
      puts `bin/axen -w #{env}-wallet.json --#{env} -u http://#{env}.axentro.io:80 -p 80 -d #{env}.sqlite3 --developer-fund=./developer_fund.yml --official-nodes=./official_nodes.yml`
    else
      puts "starting axen in systemd for env: #{env}"
      puts `sudo systemctl start axen`
    end
  end
end

SystemInstall.new.exec
