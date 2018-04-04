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

module ::E2E::Utils::Node
  def sushid(args) : String
    _args = args
      .map { |arg| arg.to_s }
      .join(" ")

    bin = File.expand_path("../../../../bin/sushid", __FILE__)

    "#{bin} #{_args}"
  end

  def node(port : Int32, is_private : Bool, connect_port : Int32?, num : Int32, _db_name : String? = nil, print = true)
    STDERR.puts "#{light_yellow("launch node")}: port(#{port}) is_private(#{is_private}) connect_port(#{connect_port}) num(#{num}) db_name(#{_db_name})" if print

    args = ["-p", port, "-w", wallet(num), "--testnet"]
    args << "-n http://127.0.0.1:#{connect_port}" if connect_port

    if db_name = _db_name
      args << "-d " + File.expand_path("../../db/#{db_name}.db", __FILE__)
    end

    if is_private
      args << "--private"
    else
      args << "-u"
      args << "http://127.0.0.1:#{port}"
    end

    bin = sushid(args)

    spawn do
      system("#{bin} &> #{log_path(num)}")
    end
  end
end
