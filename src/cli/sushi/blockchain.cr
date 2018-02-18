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

      specify_subaction!
    end

    def size
      puts_help(HELP_CONNECTING_NODE) unless node = @connect_node

      payload = {call: "blockchain_size"}.to_json

      body = rpc(node, payload)

      unless @json
        json = JSON.parse(body)
        puts_success("current blockchain size is #{json["size"]}")
      else
        puts body
      end
    end

    def all
      puts_help(HELP_CONNECTING_NODE) unless node = @connect_node

      payload = {call: "blockchain", header: @header}.to_json

      body = rpc(node, payload)

      puts_success("show current blockchain")
      puts_info(body)
    end

    def block
      puts_help(HELP_CONNECTING_NODE) unless node = @connect_node
      puts_help(HELP_BLOCK_INDEX_OR_TRANSACTION_ID) if @block_index.nil? && @transaction_id.nil?

      payload = if block_index = @block_index
                  success_message = "show a block for index: #{@block_index}"
                  {call: "block", index: block_index, header: @header}.to_json
                elsif transaction_id = @transaction_id
                  success_message = "show a block for transaction: #{@transaction_id}"
                  {call: "block", transaction_id: transaction_id, header: @header}.to_json
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
