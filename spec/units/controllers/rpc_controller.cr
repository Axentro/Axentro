require "./../../spec_helper"
require "./../utils"

include Sushi::Core
include Units::Utils
include Sushi::Core::Controllers

# def exec_internal_post(json, context, params) : HTTP::Server::Context
#   call = json["call"].to_s
#
#   case call
#   when "create_unsigned_transaction"
#     return create_unsigned_transaction(json, context, params)
#   when "create_transaction"
#     return create_transaction(json, context, params)
#   when "amount"
#     return amount(json, context, params)
#   when "blockchain_size"
#     return blockchain_size(json, context, params)
#   when "blockchain"
#     return blockchain(json, context, params)
#   when "block"
#     return block(json, context, params)
#   when "transactions"
#     return transactions(json, context, params)
#   when "transaction"
#     return transaction(json, context, params)
#   end
#
#   unpermitted_call(call, context)
# end


class MockRequest < HTTP::Request
  def initialize
    super("POST","http://54.199.249.171:3000/rpc",HTTP::Headers.new, IO::Memory.new)
  end
end

class MockResponse < HTTP::Server::Response

  @content : IO::Memory = IO::Memory.new

  def initialize
    super(@content)
  end

  def content
    @content.rewind.gets_to_end
  end
end

class MockContext < HTTP::Server::Context

  def initialize
    @request = MockRequest.new.unsafe_as(HTTP::Request)
    @response = MockResponse.new.unsafe_as(HTTP::Server::Response)
  end

end

describe RPCController do

  describe "#exec_internal_post" do

    describe "#create_unsigned_transaction" do

      it "should return the transaction as json when valid" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)

        chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
        blockchain = Blockchain.new(sender_wallet)
        blockchain.replace_chain(chain)

        rpc = RPCController.new(blockchain)

        senders = [a_sender(sender_wallet, 1000_i64)]
        recipients = [a_recipient(recipient_wallet, 10_i64)]

        payload = {
          call:       "create_unsigned_transaction",
          action:     "send",
          senders:    senders.to_json,
          recipients: recipients.to_json,
          message:    "",
        }.to_json

        json = JSON.parse(payload)

        res = rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), nil)
        res.response.output.flush
        res.response.output.close
        output = res.response.output
        case output
        when IO
          res.response.status_code.should eq(200)
          puts res.response.unsafe_as(MockResponse).content
        else
          fail "expected an io response"
        end

      end

    end
  end

    STDERR.puts "< Controllers::RPCController"
end
