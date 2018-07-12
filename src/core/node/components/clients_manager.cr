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

      id = create_id

      client_context = {id: id, address: _m_content.address}
      client = {context: client_context, socket: socket}

      @clients << client

      info "new client: #{light_green(client[:context][:id][0..7] + "...")} " +
           "(#{light_green(client[:context][:address][0..7] + "...")})"

      send(socket, M_TYPE_CLIENT_HANDSHAKE_ACCEPTED, {
        id: id,
      })
    end

    def receive_content(_content : String, from = nil)
      return unless node.phase == SETUP_PHASE::DONE

      _m_content = M_CONTENT_CLIENT_CONTENT.from_json(_content)

      action = _m_content.action
      from_id = _m_content.from_id
      content = _m_content.content

      result = false

      @blockchain.dapps.each do |dapp|
        result ||= dapp.on_message(action, from_id, content, from)
      end

      node.send_client_content(_content, from) unless result
    end

    def send_content(from_id : String, to_id : String, content : String, from = nil) : Bool
      if client = find(to_id)
        send(client[:socket], M_TYPE_CLIENT_RECEIVE, {from_id: from_id, to_id: to_id, content: content})
        return true
      end

      false
    end

    def notify(recipient : Recipient, transaction : Transaction)
      if client = find_by_address(recipient[:address])
        from_id = client[:context][:id]
        token = transaction.token
        amount = recipient[:amount]
        senders = transaction.senders.map { |s| s[:address] }.join(", ")

        message = "you've received #{amount} of #{token} from #{senders} (not confirmed)"

        send(client[:socket], M_TYPE_CLIENT_RECEIVE, {from_id: from_id, to_id: from_id, content: message})
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
