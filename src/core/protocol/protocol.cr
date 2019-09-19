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
require "../blockchain/block.cr"

module ::Sushi::Core::Protocol
  ######################################
  # MINER
  ######################################

  M_TYPE_MINER_HANDSHAKE = 0x0001

  struct MContentMinerHandshake
    JSON.mapping({
      version: Int32,
      address: String,
      mid:     String,
    })
  end

  M_TYPE_MINER_HANDSHAKE_ACCEPTED = 0x0002

  struct MContentMinerHandshakeAccepted
    JSON.mapping({
      version:    Int32,
      block:      SlowBlock,
      difficulty: Int32,
    })
  end

  M_TYPE_MINER_HANDSHAKE_REJECTED = 0x0003

  struct MContentMinerHandshakeRejected
    JSON.mapping({
      reason: String,
    })
  end

  M_TYPE_MINER_FOUND_NONCE = 0x0004

  struct MContentMinerFoundNonce
    JSON.mapping({
      nonce:     UInt64,
      timestamp: Int64,
    })
  end

  M_TYPE_MINER_BLOCK_UPDATE = 0x0005

  struct MContentMinerBlockUpdate
    JSON.mapping({
      block:      SlowBlock,
      difficulty: Int32,
    })
  end

  ######################################
  # CLIENT
  ######################################

  M_TYPE_CLIENT_HANDSHAKE = 0x1001

  struct MContentClientHandshake
    JSON.mapping({
      public_key: String,
    })
  end

  M_TYPE_CLIENT_SALT = 0x1005

  struct MContentClientSalt
    JSON.mapping({
      salt: String,
    })
  end

  M_TYPE_CLIENT_UPGRADE = 0x1006

  struct MContentClientUpgrade
    JSON.mapping({
      address:    String,
      public_key: String,
      sign_r:     String,
      sign_s:     String,
    })
  end

  M_TYPE_CLIENT_HANDSHAKE_ACCEPTED = 0x1002

  struct MContentClientHandshakeAccepted
    JSON.mapping({
      address: String,
    })
  end

  M_TYPE_CLIENT_CONTENT = 0x1003

  struct MContentClientContent
    JSON.mapping({
      action:  String,
      from:    String,
      content: String,
    })
  end

  #
  # Content structure of content of MContentClientContent
  #
  struct MContentClientMessage
    JSON.mapping({
      to:      String,
      message: String,
    })
  end

  struct MContentClientAmount
    JSON.mapping({
      token:        String,
      confirmation: Int32,
    })
  end

  #
  # Used in clients
  #
  M_TYPE_CLIENT_RECEIVE = 0x1004

  struct MContentClientReceive
    JSON.mapping({
      from:    String,
      to:      String,
      content: String,
    })
  end

  ######################################
  # CHORD
  ######################################

  M_TYPE_CHORD_JOIN = 0x0011

  struct MContentChordJoin
    JSON.mapping({
      version: Int32,
      context: Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_CHORD_JOIN_PRIVATE = 0x0012

  struct MContentChordJoinProvate
    JSON.mapping({
      version: Int32,
      context: Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_CHORD_JOIN_PRIVATE_ACCEPTED = 0x0013

  struct MContentChordJoinPrivateAccepted
    JSON.mapping({
      context: Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_CHORD_FOUND_SUCCESSOR = 0x0014

  struct MContentChordFoundSuccessor
    JSON.mapping({
      context: Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_CHORD_SEARCH_SUCCESSOR = 0x0015

  struct MContentChordSearchSuccessor
    JSON.mapping({
      context: Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_CHORD_STABILIZE_AS_SUCCESSOR = 0x0016

  struct MContentChordStabilizeAsSuccessor
    JSON.mapping({
      predecessor_context: Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_CHORD_STABILIZE_AS_PREDECESSOR = 0x0017

  struct MContentChordStabilizeAsPredecessor
    JSON.mapping({
      successor_context: Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_CHORD_JOIN_REJECTED = 0x0018

  struct MContentChordJoinRejected
    JSON.mapping({
      reason: String,
    })
  end

  ######################################
  # NODE
  ######################################

  M_TYPE_NODE_BROADCAST_TRANSACTION = 0x0101

  struct MContentNodeBroadcastTransaction
    JSON.mapping({
      transaction: Transaction,
      from:        Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_NODE_BROADCAST_BLOCK = 0x0102

  struct MContentNodeBroadcastBlock
    JSON.mapping({
      block: SlowBlock | FastBlock,
      from:  Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_NODE_REQUEST_CHAIN = 0x0103

  struct MContentNodeRequestChain
    JSON.mapping({
      latest_slow_index: Int64,
      latest_fast_index: Int64,
    })
  end

  M_TYPE_NODE_RECEIVE_CHAIN = 0x0104

  struct MContentNodeReceiveChain
    JSON.mapping({
      slowchain: Blockchain::Chain?,
      fastchain: Blockchain::Chain?,
    })
  end

  M_TYPE_NODE_ASK_REQUEST_CHAIN = 0x0105

  struct MContentNodeAskRequestChain
    JSON.mapping({
      latest_slow_index: Int64,
      latest_fast_index: Int64,
    })
  end

  M_TYPE_NODE_REQUEST_TRANSACTIONS = 0x0106

  struct MContentNodeRequestTransactions
    JSON.mapping({transactions: Array(Transaction)})
  end

  M_TYPE_NODE_RECEIVE_TRANSACTIONS = 0x0107

  struct MContentNodeReceiveTransactions
    JSON.mapping({transactions: Array(Transaction)})
  end

  M_TYPE_NODE_SEND_CLIENT_CONTENT = 0x0108

  struct MContentNodeSendClientContent
    JSON.mapping({
      content: String,
      from:    Core::NodeComponents::Chord::NodeContext,
    })
  end

  M_TYPE_NODE_BROADCAST_HEARTBEAT = 0x0109

  struct MContentNodeBroadcastHeartbeat
    JSON.mapping({
      address: String,
      public_key: String,
      hash_salt: String,
      sign_r: String,
      sign_s: String,
      from:  Core::NodeComponents::Chord::NodeContext,
    })
  end

  ######################################
  # Blockchain's setup phase
  ######################################

  enum SetupPhase
    NONE
    CONNECTING_NODES
    BLOCKCHAIN_LOADING
    BLOCKCHAIN_SYNCING
    TRANSACTION_SYNCING
    PRE_DONE
    DONE
  end

  include Block
end
