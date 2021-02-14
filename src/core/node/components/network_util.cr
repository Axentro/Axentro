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

module ::Axentro::Core::NodeComponents
  struct RemoteConnection
    property ip : String            # forwarded if found else raw
    property port : Int32           # forwarded if found else raw
    property raw_ip : String        # raw is the request.remote_address (if from an LB it will be the LB one)
    property raw_port : Int32       # raw is the request.remote_address port (if from an LB it will be the LB one)
    property forwarded_ip : String? # from the request headers with original ip forwarded from the LB
    property forwarded_port : Int32?
    property forwarded_protocol : String?

    def initialize(@ip, @port, @raw_ip, @raw_port, @forwarded_ip, @forwarded_port, @forwarded_protocol); end

    def ip_and_port
      "#{@ip}:#{@port}"
    end
  end

  module NetworkUtil
    extend self

    def get_remote_connection(request) : RemoteConnection
      raw = request.remote_address.to_s.split(":")
      raw_ip = raw.first
      raw_port = raw.last.to_i

      forwarded_ip = request.headers["X-Forwarded-For"]?
      forwarded_port = request.headers["X-Forwarded-Port"]?.try(&.to_i)
      forwarded_protocol = request.headers["X-Forwarded-Proto"]?

      ip = forwarded_ip || raw_ip
      port = forwarded_port || raw_port

      RemoteConnection.new(ip, port, raw_ip, raw_port, forwarded_ip, forwarded_port, forwarded_protocol)
    end
  end
end
