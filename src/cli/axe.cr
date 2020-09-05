# Copyright © 2017-2018 The Axentro Core developers
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

require "../cli"
require "./axe/*"

module ::Axentro::Interface::Axe
  class Root < CLI
    def sub_actions
      [
        {
          name: I18n.translate("axe.cli.wallet.title"),
          desc: I18n.translate("axe.cli.wallet.desc"),
        },
        {
          name: I18n.translate("axe.cli.blockchain.title"),
          desc: I18n.translate("axe.cli.blockchain.desc"),
        },
        {
          name: I18n.translate("axe.cli.transaction.title"),
          desc: I18n.translate("axe.cli.transaction.desc"),
        },
        {
          name: I18n.translate("axe.cli.node.title"),
          desc: I18n.translate("axe.cli.node.desc"),
        },
        {
          name: I18n.translate("axe.cli.scars.title"),
          desc: I18n.translate("axe.cli.scars.desc"),
        },
        {
          name: I18n.translate("axe.cli.token.title"),
          desc: I18n.translate("axe.cli.token.desc"),
        },
        {
          name: I18n.translate("axe.cli.config.title"),
          desc: I18n.translate("axe.cli.config.desc"),
        },
        {
          name: I18n.translate("axe.cli.pubsub.title"),
          desc: I18n.translate("axe.cli.pubsub.desc"),
        },
        {
          name: I18n.translate("axe.cli.client.title"),
          desc: I18n.translate("axe.cli.client.desc"),
        }
      ]
    end

    def option_parser
      G.op.create_option_parser([] of Options)
    end

    def run_impl(action_name)
      case action_name
      when I18n.translate("axe.cli.wallet.title"), "wt"
        return Wallet.new(
          {name: I18n.translate("axe.cli.wallet.title"), desc: I18n.translate("axe.cli.wallet.desc")},
          next_parents,
        ).run
      when I18n.translate("axe.cli.blockchain.title"), "bc"
        return Blockchain.new(
          {name: I18n.translate("axe.cli.blockchain.title"), desc: I18n.translate("axe.cli.blockchain.desc")},
          next_parents,
        ).run
      when I18n.translate("axe.cli.transaction.title"), "tx"
        return Transaction.new(
          {name: I18n.translate("axe.cli.transaction.title"), desc: I18n.translate("axe.cli.transaction.desc")},
          next_parents,
        ).run
      when I18n.translate("axe.cli.node.title"), "nd"
        return Node.new(
          {name: I18n.translate("axe.cli.node.title"), desc: I18n.translate("axe.cli.node.desc")},
          next_parents,
        ).run
      when I18n.translate("axe.cli.scars.title"), "sc"
        return Scars.new(
          {name: I18n.translate("axe.cli.scars.title"), desc: I18n.translate("axe.cli.scars.desc")},
          next_parents,
        ).run
      when I18n.translate("axe.cli.token.title"), "tk"
        return Token.new(
          {name: I18n.translate("axe.cli.token.title"), desc: I18n.translate("axe.cli.token.desc")},
          next_parents,
        ).run
      when I18n.translate("axe.cli.config.title"), "cg"
        return Config.new(
          {name: I18n.translate("axe.cli.config.title"), desc: I18n.translate("axe.cli.config.desc")},
          next_parents,
        ).run
      when I18n.translate("axe.cli.pubsub.title"), "ps"
        return Pubsub.new(
          {name: I18n.translate("axe.cli.pubsub.title"), desc: I18n.translate("axe.cli.pubsub.desc")},
          next_parents,
        ).run
      when I18n.translate("axe.cli.client.title"), "cl"
        return Client.new(
          {name: I18n.translate("axe.cli.client.title"), desc: I18n.translate("axe.cli.client.desc")},
          next_parents,
        ).run
      end

      specify_sub_action!(action_name)
    end
  end
end

include ::Axentro::Interface
include ::Axentro::Core::Keys

::Axentro::Interface::Axe::Root.new(
  {name: "axentro", desc: I18n.translate("axe.cli.title")}, [] of AxeAction
).run
