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

module ::Sushi::Core::NodeComponents
  class ClientsManager < HandleSocket
    alias ClientContext = NamedTuple(
      id: String,
      address: String?,
    )

    alias ClientContexts = Array(ClientContext)

    alias Client = NamedTuple(
      context: ClientContext,
      socket: HTTP::WebSocket,
    )

    alias Clients = Array(Client)

    getter clients : Clients = Clients.new

    def initialize(@blockchain : Blockchain)
    end

    def handshake(node, socket, _content)
      return unless node.phase == SETUP_PHASE::DONE

      _m_content = M_CONTENT_CLIENT_HANDSHAKE.from_json(_content)

      id = create_id

      client_context = {id: id, address: _m_content.address}
      client = {context: client_context, socket: socket}

      @clients << client

      info "new client: #{light_green(client[:context][:id][0..7])}"

      send(socket, M_TYPE_CLIENT_HANDSHAKE_ACCEPTED, {
        id: id,
      })
    end

    # todo
    # develop as dApps?
    def send_message(node, socket, _content)
      return unless node.phase == SETUP_PHASE::DONE

      _m_content = M_CONTENT_CLIENT_SEND_MESSAGE.from_json(_content)

      from_id = _m_content.from_id
      to_id = _m_content.to_id
      message = _m_content.message

      if client = find(to_id)
        send(client[:socket], M_TYPE_CLIENT_RECEIVE_MESSAGE, {from_id: from_id, to_id: to_id, message: message})
      end
    end

    def create_id : String
      Random::Secure.hex(16)
    end

    def clean_connection(socket)
      current_size = @clients.size
      @clients.reject! { |client| client[:socket] == socket }

      info "a client has been removed. (#{current_size} -> #{@clients.size})" if current_size > @clients.size
    end

    def find(client_id : String)
      @clients.find { |c| c[:context][:id] == client_id }
    end

    include Protocol
    include Common::Color
  end
end
