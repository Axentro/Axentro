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

module ::Sushi::Core::Models
  alias NodeContext = NamedTuple(
    id: String,
    host: String,
    port: Int32,
    ssl: Bool,
    type: String,
    is_private: Bool,
  )

  alias NodeContexts = Array(NodeContext)

  alias Node = NamedTuple(
    context: NodeContext,
    socket: HTTP::WebSocket,
  )

  alias Nodes = Array(Node)
end
