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
          name: I18n.translate("sushi.cli.wallet.title"),
          desc: I18n.translate("sushi.cli.wallet.desc"),
        },
        {
          name: I18n.translate("sushi.cli.blockchain.title"),
          desc: I18n.translate("sushi.cli.blockchain.desc"),
        },
        {
          name: I18n.translate("sushi.cli.transaction.title"),
          desc: I18n.translate("sushi.cli.transaction.desc"),
        },
        {
          name: I18n.translate("sushi.cli.node.title"),
          desc: I18n.translate("sushi.cli.node.desc"),
        },
        {
          name: I18n.translate("sushi.cli.scars.title"),
          desc: I18n.translate("sushi.cli.scars.desc"),
        },
        {
          name: I18n.translate("sushi.cli.token.title"),
          desc: I18n.translate("sushi.cli.token.desc"),
        },
        {
          name: I18n.translate("sushi.cli.config.title"),
          desc: I18n.translate("sushi.cli.config.desc"),
        },
        {
          name: I18n.translate("sushi.cli.pubsub.title"),
          desc: I18n.translate("sushi.cli.pubsub.desc"),
        },
        {
          name: I18n.translate("sushi.cli.client.title"),
          desc: I18n.translate("sushi.cli.client.desc"),
        }
      ]
    end

    def option_parser
      G.op.create_option_parser([] of Options)
    end

    def run_impl(action_name)
      case action_name
      when I18n.translate("sushi.cli.wallet.title"), "wt"
        return Wallet.new(
          {name: I18n.translate("sushi.cli.wallet.title"), desc: I18n.translate("sushi.cli.wallet.desc")},
          next_parents,
        ).run
      when I18n.translate("sushi.cli.blockchain.title"), "bc"
        return Blockchain.new(
          {name: I18n.translate("sushi.cli.blockchain.title"), desc: I18n.translate("sushi.cli.blockchain.desc")},
          next_parents,
        ).run
      when I18n.translate("sushi.cli.transaction.title"), "tx"
        return Transaction.new(
          {name: I18n.translate("sushi.cli.transaction.title"), desc: I18n.translate("sushi.cli.transaction.desc")},
          next_parents,
        ).run
      when I18n.translate("sushi.cli.node.title"), "nd"
        return Node.new(
          {name: I18n.translate("sushi.cli.node.title"), desc: I18n.translate("sushi.cli.node.desc")},
          next_parents,
        ).run
      when I18n.translate("sushi.cli.scars.title"), "sc"
        return Scars.new(
          {name: I18n.translate("sushi.cli.scars.title"), desc: I18n.translate("sushi.cli.scars.desc")},
          next_parents,
        ).run
      when I18n.translate("sushi.cli.token.title"), "tk"
        return Token.new(
          {name: I18n.translate("sushi.cli.token.title"), desc: I18n.translate("sushi.cli.token.desc")},
          next_parents,
        ).run
      when I18n.translate("sushi.cli.config.title"), "cg"
        return Config.new(
          {name: I18n.translate("sushi.cli.config.title"), desc: I18n.translate("sushi.cli.config.desc")},
          next_parents,
        ).run
      when I18n.translate("sushi.cli.pubsub.title"), "ps"
        return Pubsub.new(
          {name: I18n.translate("sushi.cli.pubsub.title"), desc: I18n.translate("sushi.cli.pubsub.desc")},
          next_parents,
        ).run
      when I18n.translate("sushi.cli.client.title"), "cl"
        return Client.new(
          {name: I18n.translate("sushi.cli.client.title"), desc: I18n.translate("sushi.cli.client.desc")},
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
  {name: "sushi", desc: I18n.translate("sushi.cli.title")}, [] of SushiAction
).run
