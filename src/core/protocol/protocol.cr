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

module ::Sushi::Core::Protocol
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
  # CLIENT
  ######################################

  M_TYPE_CLIENT_HANDSHAKE = 0x1001

  struct M_CONTENT_CLIENT_HANDSHAKE
    JSON.mapping({
      address: String?,
    })
  end

  M_TYPE_CLIENT_HANDSHAKE_ACCEPTED = 0x1002

  struct M_CONTENT_CLIENT_HANDSHAKE_ACCEPTED
    JSON.mapping({
      id: String,
    })
  end

  M_TYPE_CLIENT_SEND = 0x1003

  struct M_CONTENT_CLIENT_SEND
    JSON.mapping({
      from_id: String,
      to_id:   String,
      message: String,
    })
  end

  M_TYPE_CLIENT_RECEIVE = 0x1004

  struct M_CONTENT_CLIENT_RECEIVE
    JSON.mapping({
      from_id: String,
      to_id:   String,
      message: String,
    })
  end

  ######################################
  # CHORD
  ######################################

  M_TYPE_CHORD_JOIN = 0x0011

  struct M_CONTENT_CHORD_JOIN
    JSON.mapping({
      version: Int32,
      context: Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_CHORD_JOIN_PRIVATE = 0x0012

  struct M_CONTENT_CHORD_JOIN_PRIVATE
    JSON.mapping({
      version: Int32,
      context: Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_CHORD_JOIN_PRIVATE_ACCEPTED = 0x0013

  struct M_CONTENT_CHORD_JOIN_PRIVATE_ACCEPTED
    JSON.mapping({
      context: Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_CHORD_FOUND_SUCCESSOR = 0x0014

  struct M_CONTENT_CHORD_FOUND_SUCCESSOR
    JSON.mapping({
      context: Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_CHORD_SEARCH_SUCCESSOR = 0x0015

  struct M_CONTENT_CHORD_SEARCH_SUCCESSOR
    JSON.mapping({
      context: Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_CHORD_STABILIZE_AS_SUCCESSOR = 0x0016

  struct M_CONTENT_CHORD_STABILIZE_AS_SCCESSOR
    JSON.mapping({
      predecessor_context: Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_CHORD_STABILIZE_AS_PREDECESSOR = 0x0017

  struct M_CONTENT_CHORD_STABILIZE_AS_PREDECESSOR
    JSON.mapping({
      successor_context: Core::NodeComponents::Chord::NodeContext,
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
      from:        Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_NODE_BROADCAST_BLOCK = 0x0102

  struct M_CONTENT_NODE_BROADCAST_BLOCK
    JSON.mapping({
      block: Block,
      from:  Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_NODE_REQUEST_CHAIN = 0x0103

  struct M_CONTENT_NODE_REQUEST_CHAIN
    JSON.mapping({
      latest_index: Int64,
    })
  end

  M_TYPE_NODE_RECEIVE_CHAIN = 0x0104

  struct M_CONTENT_NODE_RECEIVE_CHAIN
    JSON.mapping({
      chain: Blockchain::Chain?,
    })
  end

  M_TYPE_NODE_ASK_REQUEST_CHAIN = 0x0105

  struct M_CONTENT_NODE_ASK_REQUEST_CHAIN
    JSON.mapping({
      latest_index: Int64,
    })
  end

  M_TYPE_NODE_REQUEST_TRANSACTIONS = 0x0106

  struct M_CONTENT_NODE_REQUEST_TRANSACTIONS
    JSON.mapping({transactions: Array(Transaction)})
  end

  M_TYPE_NODE_RECEIVE_TRANSACTIONS = 0x0107

  struct M_CONTENT_NODE_RECEIVE_TRANSACTIONS
    JSON.mapping({transactions: Array(Transaction)})
  end

  # todo
  # broadcast?
  M_TYPE_NODE_BROADCAST_MESSAGE = 0x0108

  struct M_CONTENT_NODE_BROADCAST_MESSAGE
    JSON.mapping({
      message: String,
      from:  Core::NodeComponents::Chord::NodeContext,
    })
  end

  ######################################
  # Blockchain's setup phase
  ######################################

  enum SETUP_PHASE
    NONE
    CONNECTING_NODES
    BLOCKCHAIN_LOADING
    BLOCKCHAIN_SYNCING
    TRANSACTION_SYNCING
    PRE_DONE
    DONE
  end
end
