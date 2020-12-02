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

module ::Axentro::Interface::Axe
  class Blockchain < CLI
    def sub_actions
      [
        {
          name: I18n.translate("axe.cli.blockchain.size.title"),
          desc: I18n.translate("axe.cli.blockchain.size.desc"),
        },
        {
          name: I18n.translate("axe.cli.blockchain.all.title"),
          desc: I18n.translate("axe.cli.blockchain.all.desc"),
        },
        {
          name: I18n.translate("axe.cli.blockchain.block.title"),
          desc: I18n.translate("axe.cli.blockchain.block.desc"),
        },
      ]
    end

    def option_parser
      G.op.create_option_parser([
        Options::CONNECT_NODE,
        Options::JSON,
        Options::BLOCK_INDEX,
        Options::TRANSACTION_ID,
        Options::HEADER,
        Options::CONFIG_NAME,
      ])
    end

    def run_impl(action_name)
      case action_name
      when I18n.translate("axe.cli.blockchain.size.title")
        return size
      when I18n.translate("axe.cli.blockchain.all.title")
        return all
      when I18n.translate("axe.cli.blockchain.block.title")
        return block
      end

      specify_sub_action!(action_name)
    rescue e : Exception
      puts_error e.message
    end

    def size
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node

      payload = {call: "blockchain_size"}.to_json

      body = rpc(node, payload)

      if G.op.__json
        puts body
      else
        json = JSON.parse(body)
        puts_success(I18n.translate("axe.cli.blockchain.size.messages.total_size", {size: json["totals"]["total_size"]}))
        puts_success(I18n.translate("axe.cli.blockchain.size.messages.total_slow", {size: json["totals"]["total_slow"]}))
        puts_success(I18n.translate("axe.cli.blockchain.size.messages.total_fast", {size: json["totals"]["total_fast"]}))
        puts_success(I18n.translate("axe.cli.blockchain.size.messages.transactions_fast", {size: json["totals"]["total_txns_fast"]}))
        puts_success(I18n.translate("axe.cli.blockchain.size.messages.transactions_slow", {size: json["totals"]["total_txns_slow"]}))
        puts_success(I18n.translate("axe.cli.blockchain.size.messages.difficulty", {size: json["totals"]["difficulty"]}))
        puts_success(I18n.translate("axe.cli.blockchain.size.messages.height_slow", {size: json["block_height"]["slow"]}))
        puts_success(I18n.translate("axe.cli.blockchain.size.messages.height_fast", {size: json["block_height"]["fast"]}))
      end
    end

    def all
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node

      payload = {call: "blockchain", header: G.op.__header}.to_json

      body = rpc(node, payload)

      if G.op.__json
        puts body
      else
        puts_success(I18n.translate("axe.cli.blockchain.all.messages.all"))
        puts_info(body)
      end
    end

    def block
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_BLOCK_INDEX_OR_TRANSACTION_ID) if G.op.__block_index.nil? && G.op.__transaction_id.nil?

      payload = if block_index = G.op.__block_index
                  success_message = I18n.translate("axe.cli.blockchain.block.messages.index", {block_index: G.op.__block_index})
                  {call: "block", index: block_index, header: G.op.__header}.to_json
                elsif transaction_id = G.op.__transaction_id
                  success_message = I18n.translate("axe.cli.blockchain.block.messages.transaction", {block_index: G.op.__transaction_id})
                  {call: "block", transaction_id: transaction_id, header: G.op.__header}.to_json
                else
                  puts_help(HELP_BLOCK_INDEX_OR_TRANSACTION_ID)
                end

      body = rpc(node, payload)

      if G.op.__json
        puts body
      else
        puts_success(success_message)
        puts_info(body)
      end
    end
  end
end
