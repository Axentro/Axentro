module ::Garnet::Core::Protocol

  def send(socket, t, content)
    socket.send({ type: t, content: content.to_json }.to_json)
  rescue e : Exception
    p e
  end

  ##########

  M_TYPE_HANDSHAKE_MINER = 0x0001

  struct M_CONTENT_HANDSHAKE_MINER
    JSON.mapping({
                   address: String,
                 })
  end

  ##########

  M_TYPE_HANDSHAKE_MINER_ACCEPTED = 0x0002

  struct M_CONTENT_HANDSHAKE_MINER_ACCEPTED
    JSON.mapping({
                   difficulty: Int32,
                   block: Block,
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
                   block: Block,
                 })
  end

  ##########

  M_TYPE_HANDSHAKE_NODE  = 0x0011

  struct M_CONTENT_HANDSHAKE_NODE
    JSON.mapping({
                   context: Models::NodeContext,
                   known_nodes: Models::NodeContexts,
                 })
  end

  ##########

  M_TYPE_HANDSHAKE_NODE_ACCEPTED = 0x0012

  struct M_CONTENT_HANDSHAKE_NODE_ACCEPTED
    JSON.mapping({
                   context: Models::NodeContext,
                   node_list: Models::NodeContexts,
                   last_index: UInt32,
                 })
  end

  ##########

  M_TYPE_HANDSHAKE_NODE_REJECTED = 0x0013

  struct M_CONTENT_HANDSHAKE_NODE_REJECTED
    JSON.mapping({
                   context: Models::NodeContext,
                   reason: String,
                 })
  end

  ##########

  M_TYPE_ADD_TRANSACTION = 0x0014

  struct M_CONTENT_ADD_TRANSACTION
    JSON.mapping({
                   transaction: Transaction,
                 })
  end

  ##########

  M_TYPE_BROADCAST_BLOCK = 0x0015

  struct M_CONTENT_BROADCAST_BLOCK
    JSON.mapping({
                   block: Block,
                 })
  end

  ##########

  M_TYPE_REQUEST_CHAIN = 0x0016

  struct M_CONTENT_REQUEST_CHAIN
    JSON.mapping({
                   last_index: UInt32,
                 })
  end

  ##########

  M_TYPE_RECIEVE_CHAIN = 0x0017

  struct M_CONTENT_RECIEVE_CHAIN
    JSON.mapping({
                   chain: Models::Chain,
                 })
  end

  #### Running phases ####

  PHASE_NODE_SYNCING = 1
  PHASE_NODE_RUNNING = 2
end
