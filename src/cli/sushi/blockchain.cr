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

module ::Sushi::Interface::Sushi
  class Blockchain < CLI
    def sub_actions
      [
        {
          name: "size",
          desc: "show current blockchain size",
        },
        {
          name: "all",
          desc: "get whole blockchain. headers (without transactions) only with --header option",
        },
        {
          name: "block",
          desc: "get a block for a specified index or transaction id",
        },
      ]
    end

    def option_parser
      create_option_parser([
        Options::CONNECT_NODE,
        Options::JSON,
        Options::BLOCK_INDEX,
        Options::TRANSACTION_ID,
        Options::HEADER,
      ])
    end

    def run_impl(action_name)
      case action_name
      when "size"
        return size
      when "all"
        return all
      when "block"
        return block
      end

      specify_sub_action!(action_name)
    rescue e : Exception
      puts_error e.message    
    end

    def size
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node

      payload = {call: "blockchain_size"}.to_json

      body = rpc(node, payload)

      unless __json
        json = JSON.parse(body)
        puts_success("current blockchain size is #{json["size"]}")
      else
        puts body
      end
    end

    def all
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node

      payload = {call: "blockchain", header: __header}.to_json

      body = rpc(node, payload)

      puts_success("show current blockchain")
      puts_info(body)
    end

    def block
      puts_help(HELP_CONNECTING_NODE) unless node = __connect_node
      puts_help(HELP_BLOCK_INDEX_OR_TRANSACTION_ID) if __block_index.nil? && __transaction_id.nil?

      payload = if block_index = __block_index
                  success_message = "show a block for index: #{__block_index}"
                  {call: "block", index: block_index, header: __header}.to_json
                elsif transaction_id = __transaction_id
                  success_message = "show a block for transaction: #{__transaction_id}"
                  {call: "block", transaction_id: transaction_id, header: __header}.to_json
                else
                  puts_help(HELP_BLOCK_INDEX_OR_TRANSACTION_ID)
                end

      body = rpc(node, payload)

      puts_success(success_message)
      puts_info(body)
    end

    include GlobalOptionParser
  end
end
