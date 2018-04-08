module ::Sushi::Core::Protocol
  def send(socket, t, content)
    socket.send({type: t, content: content.to_json}.to_json)
  end

  ######################################
  # MINER
  ######################################

  M_TYPE_MINER_HANDSHAKE = 0x0001

  struct M_CONTENT_MINER_HANDSHAKE
    JSON.mapping({
      version: Int32,
      address: String,
    })
  end

  M_TYPE_MINER_HANDSHAKE_ACCEPTED = 0x0002

  struct M_CONTENT_MINER_HANDSHAKE_ACCEPTED
    JSON.mapping({
      version:    Int32,
      block:      Block,
      difficulty: Int32,
    })
  end

  M_TYPE_MINER_HANDSHAKE_REJECTED = 0x0003

  struct M_CONTENT_MINER_HANDSHAKE_REJECTED
    JSON.mapping({
      reason: String,
    })
  end

  M_TYPE_MINER_FOUND_NONCE = 0x0004

  struct M_CONTENT_MINER_FOUND_NONCE
    JSON.mapping({
      nonce: UInt64,
    })
  end

  M_TYPE_MINER_BLOCK_UPDATE = 0x0005

  struct M_CONTENT_MINER_BLOCK_UPDATE
    JSON.mapping({
      block:      Block,
      difficulty: Int32,
    })
  end

  ######################################
  # CHORD
  ######################################

  M_TYPE_CHORD_JOIN = 0x0011

  struct M_CONTENT_CHORD_JOIN
    JSON.mapping({
      version: Int32,
      context: Models::NodeContext,
    })
  end

  M_TYPE_CHORD_JOIN_PRIVATE = 0x0012

  struct M_CONTENT_CHORD_JOIN_PRIVATE
    JSON.mapping({
      version: Int32,
      context: Models::NodeContext,
    })
  end

  M_TYPE_CHORD_JOIN_PRIVATE_ACCEPTED = 0x0013

  struct M_CONTENT_CHORD_JOIN_PRIVATE_ACCEPTED
    JSON.mapping({
      context: Models::NodeContext,
    })
  end

  M_TYPE_CHORD_FOUND_SUCCESSOR = 0x0014

  struct M_CONTENT_CHORD_FOUND_SUCCESSOR
    JSON.mapping({
      context: Models::NodeContext,
    })
  end

  M_TYPE_CHORD_SEARCH_SUCCESSOR = 0x0015

  struct M_CONTENT_CHORD_SEARCH_SUCCESSOR
    JSON.mapping({
      context: Models::NodeContext,
    })
  end

  M_TYPE_CHORD_STABILIZE_AS_SUCCESSOR = 0x0016

  struct M_CONTENT_CHORD_STABILIZE_AS_SCCESSOR
    JSON.mapping({
      predecessor_context: Models::NodeContext,
    })
  end

  M_TYPE_CHORD_STABILIZE_AS_PREDECESSOR = 0x0017

  struct M_CONTENT_CHORD_STABILIZE_AS_PREDECESSOR
    JSON.mapping({
      successor_context: Models::NodeContext,
    })
  end

  M_TYPE_CHORD_JOIN_REJECTED = 0x0018

  struct M_CONTENT_CHORD_JOIN_REJECTED
    JSON.mapping({
                   reason: String,
                 })
  end

  ######################################
  # NODE
  ######################################

  M_TYPE_NODE_BROADCAST_TRANSACTION = 0x0101

  struct M_CONTENT_NODE_BROADCAST_TRANSACTION
    JSON.mapping({
      transaction: Transaction,
      from:        NodeContext,
    })
  end

  M_TYPE_NODE_BROADCAST_BLOCK = 0x0102

  struct M_CONTENT_NODE_BROADCAST_BLOCK
    JSON.mapping({
      block: Block,
      from:  NodeContext,
    })
  end

  M_TYPE_NODE_REQUEST_CHAIN = 0x0103

  struct M_CONTENT_NODE_REQUEST_CHAIN
    JSON.mapping({
      latest_index: Int64,
    })
  end

  M_TYPE_NODE_RECIEVE_CHAIN = 0x0104

  struct M_CONTENT_NODE_RECIEVE_CHAIN
    JSON.mapping({
      chain: Models::Chain?,
    })
  end

  FLAG_NONE               = 0
  FLAG_CONNECTING_NODES   = 1
  FLAG_BLOCKCHAIN_LOADING = 2
  FLAG_BLOCKCHAIN_SYNCING = 3
  FLAG_SETUP_PRE_DONE     = 4
  FLAG_SETUP_DONE         = 5
end
