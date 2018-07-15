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
      address: String,
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

    def handshake(socket, _content)
      return unless node.phase == SETUP_PHASE::DONE

      _m_content = M_CONTENT_CLIENT_HANDSHAKE.from_json(_content)

      client_context = {address: _m_content.address}
      client = {context: client_context, socket: socket}

      @clients << client

      info "new client: #{light_green(client[:context][:address][0..7] + "...")}"

      send(socket, M_TYPE_CLIENT_HANDSHAKE_ACCEPTED, {address: client_context[:address]})
    end

    def receive_content(_content : String, from = nil)
      return unless node.phase == SETUP_PHASE::DONE

      _m_content = M_CONTENT_CLIENT_CONTENT.from_json(_content)

      action = _m_content.action
      from_address = _m_content.from
      content = _m_content.content

      result = false

      @blockchain.dapps.each do |dapp|
        result ||= dapp.on_message(action, from_address, content, from)
      end

      node.send_client_content(_content, from) unless result
    end

    def send_content(from_address : String, to : String, content : String, from = nil) : Bool
      if client = find_by_address(to)
        send(client[:socket], M_TYPE_CLIENT_RECEIVE, {from: from_address, to: to, content: content})
        return true
      end

      false
    end

    def clean_connection(socket)
      current_size = @clients.size
      @clients.reject! { |client| client[:socket] == socket }

      info "a client has been removed. (#{current_size} -> #{@clients.size})" if current_size > @clients.size
    end

    def find_by_address(address : String)
      @clients.find { |c| c[:context][:address] == address }
    end

    private def node
      @blockchain.node
    end

    include Protocol
    include TransactionModels
    include Common::Color
  end
end
