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

require "./logger"
require "../protocol/*"

module ::Axentro::Core
  abstract class HandleSocket
    def send(socket, t, content, use_msgpack=false)
      json_content = content.to_json
      
      if use_msgpack
        transport = Transport.new(t, json_content)
        socket.send(transport.to_msgpack)
      else
        m = {type: t, content: json_content}
        socket.send(m.to_json)
      end  
    rescue e : Exception
      handle_exception(socket, e)
    end

    def handle_exception(socket : HTTP::WebSocket, e : Exception)
      debug "Exception triggered when sending message: #{e}"
      case e
      when IO::Error
        clean_connection(socket)
      when Errno
        if error_message = e.message
          if error_message == "Error writing to socket: Broken pipe"
            clean_connection(socket)
          elsif error_message == "Error writing to socket: Protocol wrong type for socket"
            clean_connection(socket)
          elsif error_message == "Connection refused"
            clean_connection(socket)
          elsif error_message == "Connection reset by peer"
            clean_connection(socket)
          else
            show_exception(e)
          end
        else
          show_exception(e)
        end
      else
        show_exception(e)
      end
    end

    def show_exception(e : Exception)
      if error_message = e.message
        error error_message
      else
        error "unknown error"
      end

      if backtrace = e.backtrace
        error backtrace.join("\n")
      end
    end

    abstract def clean_connection(socket)

    include Logger
    include Protocol
  end
end
