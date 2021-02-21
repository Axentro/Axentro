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
require "../blockchain/block.cr"
require "../blockchain/rewards/models.cr"
require "../node/components/slow_sync.cr"

module ::Axentro::Core::Protocol
  ######################################
  # TRANSPORT
  ######################################

  struct Transport(T)
    include JSON::Serializable
    include MessagePack::Serializable
    property type : TransportType
    property message : T
    def initialize(@type, @message); end
  end

  enum TransportType
    M_TYPE_MINER_HANDSHAKE                         = 0x0001
    M_TYPE_MINER_HANDSHAKE_ACCEPTED                = 0x0002
    M_TYPE_MINER_HANDSHAKE_REJECTED                = 0x0003
    M_TYPE_MINER_FOUND_NONCE                       = 0x0004
    M_TYPE_MINER_BLOCK_UPDATE                      = 0x0005
    M_TYPE_MINER_BLOCK_DIFFICULTY_ADJUST           = 0x0006
    M_TYPE_MINER_BLOCK_INVALID                     = 0x0007
    M_TYPE_MINER_EXCEED_RATE                       = 0x0008
    M_TYPE_CLIENT_HANDSHAKE                        = 0x1001
    M_TYPE_CLIENT_SALT                             = 0x1005
    M_TYPE_CLIENT_UPGRADE                          = 0x1006
    M_TYPE_CLIENT_HANDSHAKE_ACCEPTED               = 0x1002
    M_TYPE_CLIENT_CONTENT                          = 0x1003
    M_TYPE_CLIENT_RECEIVE                          = 0x1004
    M_TYPE_CHORD_JOIN                              = 0x0011
    M_TYPE_CHORD_JOIN_PRIVATE                      = 0x0012
    M_TYPE_CHORD_JOIN_PRIVATE_ACCEPTED             = 0x0013
    M_TYPE_CHORD_FOUND_SUCCESSOR                   = 0x0014
    M_TYPE_CHORD_SEARCH_SUCCESSOR                  = 0x0015
    M_TYPE_CHORD_STABILIZE_AS_SUCCESSOR            = 0x0016
    M_TYPE_CHORD_STABILIZE_AS_PREDECESSOR          = 0x0017
    M_TYPE_CHORD_JOIN_REJECTED                     = 0x0018
    M_TYPE_CHORD_BROADCAST_NODE_JOINED             = 0x0019
    M_TYPE_CHORD_RECONNECT                         = 0x0020
    M_TYPE_CHORD_RECONNECT_PRIVATE                 = 0x0021
    M_TYPE_NODE_BROADCAST_TRANSACTION              = 0x0101
    M_TYPE_NODE_BROADCAST_BLOCK                    = 0x0102
    M_TYPE_NODE_REQUEST_CHAIN                      = 0x0103
    M_TYPE_NODE_RECEIVE_CHAIN                      = 0x0104
    M_TYPE_NODE_REQUEST_TRANSACTIONS               = 0x0106
    M_TYPE_NODE_RECEIVE_TRANSACTIONS               = 0x0107
    M_TYPE_NODE_SEND_CLIENT_CONTENT                = 0x0108
    M_TYPE_NODE_BROADCAST_MINER_NONCE              = 0x0110
    M_TYPE_NODE_REQUEST_MINER_NONCES               = 0x0111
    M_TYPE_NODE_RECEIVE_MINER_NONCES               = 0x0112
    M_TYPE_NODE_REQUEST_CHAIN_SIZE                 = 0x0113
    M_TYPE_NODE_RECEIVE_CHAIN_SIZE                 = 0x0114
    M_TYPE_NODE_REQUEST_VALIDATION_CHALLENGE       = 0x0115
    M_TYPE_NODE_RECEIVE_VALIDATION_CHALLENGE       = 0x0116
    M_TYPE_NODE_REQUEST_VALIDATION_CHALLENGE_CHECK = 0x0117
    M_TYPE_NODE_REQUEST_VALIDATION_SUCCESS         = 0x0118
    M_TYPE_NODE_BROADCAST_REJECT_BLOCK             = 0x0119
  end

  ######################################
  # MINER
  ######################################

  M_TYPE_MINER_HANDSHAKE = 0x0001

  struct MContentMinerHandshake
    include JSON::Serializable
    include MessagePack::Serializable
    property version : String
    property address : String
    property mid : String
  end

  M_TYPE_MINER_HANDSHAKE_ACCEPTED = 0x0002

  struct MContentMinerHandshakeAccepted
    include JSON::Serializable
    include MessagePack::Serializable
    property version : String
    property block : SlowBlock
    property difficulty : Int32
  end

  M_TYPE_MINER_HANDSHAKE_REJECTED = 0x0003

  struct MContentMinerHandshakeRejected
    include JSON::Serializable
    include MessagePack::Serializable
    property reason : String
  end

  M_TYPE_MINER_FOUND_NONCE = 0x0004

  struct MContentMinerFoundNonce
    include JSON::Serializable
    include MessagePack::Serializable
    property nonce : MinerNonce
  end

  M_TYPE_MINER_BLOCK_UPDATE = 0x0005

  struct MContentMinerBlockUpdate
    include JSON::Serializable
    include MessagePack::Serializable
    property block : SlowBlock
    property difficulty : Int32
  end

  M_TYPE_MINER_BLOCK_DIFFICULTY_ADJUST = 0x0006

  struct MContentMinerBlockDifficultyAdjust
    include JSON::Serializable
    include MessagePack::Serializable
    property block : SlowBlock
    property difficulty : Int32
    property reason : String
  end

  M_TYPE_MINER_BLOCK_INVALID = 0x0007

  struct MContentMinerBlockInvalid
    include JSON::Serializable
    include MessagePack::Serializable
    property block : SlowBlock
    property difficulty : Int32
    property reason : String
  end

  M_TYPE_MINER_EXCEED_RATE = 0x0008

  struct MContentMinerExceedRate
    include JSON::Serializable
    include MessagePack::Serializable
    property reason : String
    property remaining_duration : Int32
  end

  ######################################
  # CLIENT
  ######################################

  M_TYPE_CLIENT_HANDSHAKE = 0x1001

  struct MContentClientHandshake
    include JSON::Serializable
    include MessagePack::Serializable
    property public_key : String
  end

  M_TYPE_CLIENT_SALT = 0x1005

  struct MContentClientSalt
    include JSON::Serializable
    include MessagePack::Serializable
    property salt : String
  end

  M_TYPE_CLIENT_UPGRADE = 0x1006

  struct MContentClientUpgrade
    include JSON::Serializable
    include MessagePack::Serializable
    property address : String
    property public_key : String
    property signature : String
  end

  M_TYPE_CLIENT_HANDSHAKE_ACCEPTED = 0x1002

  struct MContentClientHandshakeAccepted
    include JSON::Serializable
    include MessagePack::Serializable
    property address : String
  end

  M_TYPE_CLIENT_CONTENT = 0x1003

  struct MContentClientContent
    include JSON::Serializable
    include MessagePack::Serializable
    property action : String
    property from : String
    property content : String
  end

  #
  # Content structure of content of MContentClientContent
  #
  struct MContentClientMessage
    include JSON::Serializable
    include MessagePack::Serializable
    property to : String
    property message : String
  end

  struct MContentClientAmount
    include JSON::Serializable
    include MessagePack::Serializable
    property token : String
    property confirmation : Int32
  end

  #
  # Used in clients
  #
  M_TYPE_CLIENT_RECEIVE = 0x1004

  struct MContentClientReceive
    include JSON::Serializable
    include MessagePack::Serializable
    property from : String
    property to : String
    property content : String
  end

  ######################################
  # CHORD
  ######################################

  M_TYPE_CHORD_JOIN = 0x0011

  struct MContentChordJoin
    include JSON::Serializable
    include MessagePack::Serializable
    property version : String
    property context : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_CHORD_JOIN_PRIVATE = 0x0012

  struct MContentChordJoinPrivate
    include JSON::Serializable
    include MessagePack::Serializable
    property version : String
    property context : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_CHORD_JOIN_PRIVATE_ACCEPTED = 0x0013

  struct MContentChordJoinPrivateAccepted
    include JSON::Serializable
    include MessagePack::Serializable
    property context : Core::NodeComponents::Chord::NodeContext
    # property is_reconnect : Bool
  end

  M_TYPE_CHORD_FOUND_SUCCESSOR = 0x0014

  struct MContentChordFoundSuccessor
    include JSON::Serializable
    include MessagePack::Serializable
    property context : Core::NodeComponents::Chord::NodeContext
    # property is_reconnect : Bool
  end

  M_TYPE_CHORD_SEARCH_SUCCESSOR = 0x0015

  struct MContentChordSearchSuccessor
    include JSON::Serializable
    include MessagePack::Serializable
    property context : Core::NodeComponents::Chord::NodeContext
    # property is_reconnect : Bool
  end

  M_TYPE_CHORD_STABILIZE_AS_SUCCESSOR = 0x0016

  struct MContentChordStabilizeAsSuccessor
    include JSON::Serializable
    include MessagePack::Serializable
    property predecessor_context : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_CHORD_STABILIZE_AS_PREDECESSOR = 0x0017

  struct MContentChordStabilizeAsPredecessor
    include JSON::Serializable
    include MessagePack::Serializable
    property successor_context : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_CHORD_JOIN_REJECTED = 0x0018

  struct MContentChordJoinRejected
    include JSON::Serializable
    include MessagePack::Serializable
    property reason : String
  end

  M_TYPE_CHORD_BROADCAST_NODE_JOINED = 0x0019

  struct MContentChordBroadcastNodeJoined
    include JSON::Serializable
    include MessagePack::Serializable
    property nodes : Array(Core::NodeComponents::Chord::NodeContext)
    property from : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_CHORD_RECONNECT = 0x0020

  M_TYPE_CHORD_RECONNECT_PRIVATE = 0x0021

  ######################################
  # NODE
  ######################################

  M_TYPE_NODE_BROADCAST_TRANSACTION = 0x0101

  struct MContentNodeBroadcastTransaction
    include JSON::Serializable
    include MessagePack::Serializable
    property transaction : Transaction
    property from : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_NODE_BROADCAST_BLOCK = 0x0102

  struct MContentNodeBroadcastBlock
    include JSON::Serializable
    include MessagePack::Serializable
    property block : SlowBlock | FastBlock
    property from : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_NODE_REQUEST_CHAIN = 0x0103

  struct MContentNodeRequestChain
    include JSON::Serializable
    include MessagePack::Serializable
    property start_slow_index : Int64
    property start_fast_index : Int64
    property chunk_size : Int32
  end

  M_TYPE_NODE_RECEIVE_CHAIN = 0x0104

  struct MContentNodeReceiveChain
    include JSON::Serializable
    include MessagePack::Serializable
    property blocks : Blockchain::Chain?
    property chunk_size : Int32
  end

  M_TYPE_NODE_REQUEST_TRANSACTIONS = 0x0106

  struct MContentNodeRequestTransactions
    include JSON::Serializable
    include MessagePack::Serializable
    property transactions : Array(Transaction)
  end

  M_TYPE_NODE_RECEIVE_TRANSACTIONS = 0x0107

  struct MContentNodeReceiveTransactions
    include JSON::Serializable
    include MessagePack::Serializable
    property transactions : Array(Transaction)
  end

  M_TYPE_NODE_SEND_CLIENT_CONTENT = 0x0108

  struct MContentNodeSendClientContent
    include JSON::Serializable
    include MessagePack::Serializable
    property content : String
    property from : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_NODE_BROADCAST_MINER_NONCE = 0x0110

  struct MContentNodeBroadcastMinerNonce
    include JSON::Serializable
    include MessagePack::Serializable
    property nonce : MinerNonce
    property from : Core::NodeComponents::Chord::NodeContext
  end

  M_TYPE_NODE_REQUEST_MINER_NONCES = 0x0111

  struct MContentNodeRequestMinerNonces
    include JSON::Serializable
    include MessagePack::Serializable
    property nonces : Array(MinerNonce)
  end

  M_TYPE_NODE_RECEIVE_MINER_NONCES = 0x0112

  struct MContentNodeReceiveMinerNonces
    include JSON::Serializable
    include MessagePack::Serializable
    property nonces : Array(MinerNonce)
  end

  M_TYPE_NODE_REQUEST_CHAIN_SIZE = 0x0113

  struct MContentNodeRequestChainSize
    include JSON::Serializable
    include MessagePack::Serializable
    property latest_slow_index : Int64
    property latest_fast_index : Int64
    property chunk_size : Int32
  end

  M_TYPE_NODE_RECEIVE_CHAIN_SIZE = 0x0114

  struct MContentNodeReceiveChainSize
    include JSON::Serializable
    include MessagePack::Serializable

    property slowchain_start_index : Int64
    property fastchain_start_index : Int64
    property slow_target_index : Int64
    property fast_target_index : Int64
    property chunk_size : Int32
  end

  M_TYPE_NODE_REQUEST_VALIDATION_CHALLENGE = 0x0115

  struct MContentNodeRequestValidationChallenge
    include JSON::Serializable
    include MessagePack::Serializable
    property latest_slow_index : Int64
    property latest_fast_index : Int64
  end

  M_TYPE_NODE_RECEIVE_VALIDATION_CHALLENGE = 0x0116

  struct MContentNodeReceiveValidationChallenge
    include JSON::Serializable
    include MessagePack::Serializable
    property validation_blocks : Array(Int64)
  end

  M_TYPE_NODE_REQUEST_VALIDATION_CHALLENGE_CHECK = 0x0117

  struct MContentNodeRequestValidationChallengeCheck
    include JSON::Serializable
    include MessagePack::Serializable
    property validation_hash : String
  end

  M_TYPE_NODE_REQUEST_VALIDATION_SUCCESS = 0x0118

  M_TYPE_NODE_BROADCAST_REJECT_BLOCK = 0x0119

  struct MContentNodeBroadcastRejectBlock
    include JSON::Serializable
    include MessagePack::Serializable
    property reject_block : RejectBlock
    property from : Core::NodeComponents::Chord::NodeContext
  end

  ######################################
  # Blockchain's setup phase
  ######################################

  enum SetupPhase
    NONE
    BLOCKCHAIN_LOADING
    CONNECTING_NODES
    BLOCKCHAIN_SYNCING
    TRANSACTION_SYNCING
    MINER_NONCE_SYNCING
    PRE_DONE
    DONE
  end

  include Block
  include ::Axentro::Core::NodeComponents
  include ::Axentro::Core::NonceModels
end
