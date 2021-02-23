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

module ::Axentro::Core::NodeComponents::Metrics
  # Current connections
  # miners, nodes
  Crometheus.alias ConnectedGauge = Crometheus::Gauge[:kind]
  METRICS_CONNECTED_GAUGE = ConnectedGauge.new(:axnt_connected, "Currently connected (miners, public_nodes, private_nodes)")

  # Miners
  # joined, removed, banned, rate_limited, decrease_difficulty, increase_difficulty
  Crometheus.alias MinerConnectionCounter = Crometheus::Counter[:kind]
  METRICS_MINERS_COUNTER = MinerConnectionCounter.new(:axnt_miner_connections, "Miner connections (joined, removed, banned, rate_limited, increase_difficulty, decrease_difficulty, old_miner)")

  Crometheus.alias MinersBannedGauge = Crometheus::Gauge[:kind]
  METRICS_MINERS_BANNED_GAUGE = MinersBannedGauge.new(:axnt_miners_banned, "Currently banned")

  # Nonces
  # valid, invalid
  Crometheus.alias NoncesCounter = Crometheus::Counter[:kind]
  METRICS_NONCES_COUNTER = NoncesCounter.new(:axnt_nonces_recieved, "Nonces received (valid, invalid)")

  # Blocks
  # fast, slow
  Crometheus.alias BlocksCounter = Crometheus::Counter[:kind]
  METRICS_BLOCKS_COUNTER = BlocksCounter.new(:axnt_blocks_created, "Blocks created (fast, slow)")

  # Nodes
  # joined, removed, sync_requested
  Crometheus.alias NodeConnectionCounter = Crometheus::Counter[:kind]
  METRICS_NODES_COUNTER = NodeConnectionCounter.new(:axnt_node_connections, "Node connections (joined, removed, sync_requested)")

  # Transactions
  # fast, slow, rejected
  Crometheus.alias TransactionsCounter = Crometheus::Counter[:kind]
  METRICS_TRANSACTIONS_COUNTER = TransactionsCounter.new(:axnt_transactions_received, "Transactions received (fast, slow, rejected)")
end
