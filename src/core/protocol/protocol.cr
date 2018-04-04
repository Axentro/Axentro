module ::Sushi::Core::Protocol
  def send(socket, t, content)
    socket.send({type: t, content: content.to_json}.to_json)
  end

  ##########

  M_TYPE_HANDSHAKE_MINER = 0x0001

  struct M_CONTENT_HANDSHAKE_MINER
    JSON.mapping({
      version: Int32,
      address: String,
    })
  end

  ##########

  M_TYPE_HANDSHAKE_MINER_ACCEPTED = 0x0002

  struct M_CONTENT_HANDSHAKE_MINER_ACCEPTED
    JSON.mapping({
      version:    Int32,
      block:      Block,
      difficulty: Int32,
    })
  end

  ##########

  M_TYPE_HANDSHAKE_MINER_REJECTED = 0x0003

  struct M_CONTENT_HANDSHAKE_MINER_REJECTED
    JSON.mapping({
      reason: String,
    })
  end

  ##########

  M_TYPE_FOUND_NONCE = 0x0004

  struct M_CONTENT_FOUND_NONCE
    JSON.mapping({
      nonce: UInt64,
    })
  end

  ##########

  M_TYPE_BLOCK_UPDATE = 0x0005

  struct M_CONTENT_BLOCK_UPDATE
    JSON.mapping({
      block:      Block,
      difficulty: Int32,
    })
  end

  ##########

  M_TYPE_CHORD_JOIN = 0x1001

  struct M_CONTENT_CHORD_JOIN
    JSON.mapping({
      version: Int32,
      context: Models::NodeContext,
    })
  end

  M_TYPE_CHORD_FOUND_SUCCESSOR = 0x1002

  struct M_CONTENT_CHORD_FOUND_SUCCESSOR
    JSON.mapping({
      context: Models::NodeContext,
    })
  end

  M_TYPE_CHORD_SEARCH_SUCCESSOR = 0x1003

  struct M_CONTENT_CHORD_SEARCH_SUCCESSOR
    JSON.mapping({
      context: Models::NodeContext,
    })
  end

  M_TYPE_CHORD_STABILIZE_AS_SUCCESSOR = 0x1005

  struct M_CONTENT_CHORD_STABILIZE_AS_SCCESSOR
    JSON.mapping({
      predecessor_context: Models::NodeContext,
    })
  end

  M_TYPE_CHORD_STABILIZE_AS_PREDECESSOR = 0x1006

  struct M_CONTENT_CHORD_STABILIZE_AS_PREDECESSOR
    JSON.mapping({
      successor_context: Models::NodeContext,
    })
  end

  # todo
  M_TYPE_CHORD_ASK_SUCCESSOR = 0x1007

  struct M_CONTENT_CHORD_AS_SUCCESSOR
    JSON.mapping({
                   context: Models::NodeContext,
                 })
  end

  ##########

  M_TYPE_HANDSHAKE_NODE = 0x0011

  struct M_CONTENT_HANDSHAKE_NODE
    JSON.mapping({
      version: Int32,
      context: Models::NodeContext,
    })
  end

  ##########

  M_TYPE_HANDSHAKE_NODE_ACCEPTED = 0x0012

  struct M_CONTENT_HANDSHAKE_NODE_ACCEPTED
    JSON.mapping({
      context:      Models::NodeContext,
      latest_index: Int64,
    })
  end

  ##########

  M_TYPE_HANDSHAKE_NODE_REJECTED = 0x0013

  struct M_CONTENT_HANDSHAKE_NODE_REJECTED
    JSON.mapping({
      context: Models::NodeContext,
      reason:  String,
    })
  end

  ##########

  M_TYPE_BROADCAST_TRANSACTION = 0x0014

  struct M_CONTENT_BROADCAST_TRANSACTION
    JSON.mapping({
      transaction: Transaction,
      known_nodes: Models::NodeContexts,
    })
  end

  ##########

  M_TYPE_BROADCAST_BLOCK = 0x0015

  struct M_CONTENT_BROADCAST_BLOCK
    JSON.mapping({
      block:       Block,
      known_nodes: Models::NodeContexts,
    })
  end

  ##########

  M_TYPE_REQUEST_CHAIN = 0x0016

  struct M_CONTENT_REQUEST_CHAIN
    JSON.mapping({
      latest_index: Int64,
    })
  end

  ##########

  M_TYPE_RECIEVE_CHAIN = 0x0017

  struct M_CONTENT_RECIEVE_CHAIN
    JSON.mapping({
      chain: Models::Chain?,
    })
  end

  ##########

  M_TYPE_REQUEST_NODES = 0x0018

  struct M_CONTENT_REQUEST_NODES
    JSON.mapping({
      known_nodes:       Models::NodeContexts,
      request_nodes_num: Int32,
    })
  end

  ##########

  M_TYPE_RECIEVE_NODES = 0x0019

  struct M_CONTENT_RECIEVE_NODES
    JSON.mapping({
      node_list: Models::NodeContexts,
    })
  end

  # ### Flags for node status ####

  FLAG_NONE               = 0
  FLAG_CONNECTING_NODES   = 1
  FLAG_BLOCKCHAIN_LOADING = 2
  FLAG_BLOCKCHAIN_SYNCING = 3
  FLAG_SETUP_PRE_DONE     = 4
  FLAG_SETUP_DONE         = 5
end
