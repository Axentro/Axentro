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

require "../cli"
require "./sushi/*"

module ::Sushi::Interface::Sushi
  class Root < CLI
    def sub_actions
      [
        {
          name: "wallet",
          desc: "create, encrypt or decrypt your wallet (wt for short)",
        },
        {
          name: "blockchain",
          desc: "get a whole blockchain or each block (bc for short)",
        },
        {
          name: "transaction",
          desc: "get or create transactions (tx for short)",
        },
        {
          name: "node",
          desc: "show information of nodes (nd for short)",
        },
        {
          name: "scars",
          desc: "SushiCon Address Resolution System (SCARS), buy/sell a readable domain for your address (sc for short)",
        },
        {
          name: "token",
          desc: "create tokens.",
        },
        {
          name: "config",
          desc: "save default configuration used by sushi, sushid and sushim (cg for short)",
        },
        {
          name: "pubsub",
          desc: "receive blocks in realtime",
        },
        {
          name: "client",
          desc: "connect to node as peer clients",
        },
      ]
    end

    def option_parser
      G.op.create_option_parser([
        Options::JSON,
      ])
    end

    def run_impl(action_name)
      case action_name
      when "wallet", "wt"
        return Wallet.new(
          {name: "wallet", desc: "create, encrypt or decrypt your wallet"},
          next_parents,
        ).run
      when "blockchain", "bc"
        return Blockchain.new(
          {name: "blockchain", desc: "get a whole blockchain or each block"},
          next_parents,
        ).run
      when "transaction", "tx"
        return Transaction.new(
          {name: "transaction", desc: "get or create transactions"},
          next_parents,
        ).run
      when "node", "nd"
        return Node.new(
          {name: "node", desc: "show information of nodes"},
          next_parents,
        ).run
      when "scars", "sc"
        return Scars.new(
          {name: "scars", desc: "SushiCon Address Resolution System (SCARS), buy/sell a readable domain for your address"},
          next_parents,
        ).run
      when "token", "tk"
        return Token.new(
          {name: "token", desc: "create tokens."},
          next_parents,
        ).run
      when "config", "cg"
        return Config.new(
          {name: "config", desc: "save default configuration used by sushi, sushid and sushim"},
          next_parents,
        ).run
      when "pubsub", "ps"
        return Pubsub.new(
          {name: "pubsub", desc: "receive blocks in realtime"},
          next_parents,
        ).run
      when "client", "cl"
        return Client.new(
          {name: "client", desc: "connect to node as peer clients"},
          next_parents,
        ).run
      end

      specify_sub_action!(action_name)
    end
  end
end

include ::Sushi::Interface
include ::Sushi::Core::Keys

::Sushi::Interface::Sushi::Root.new(
  {name: "sushi", desc: "sushi's command line client"}, [] of SushiAction
).run
