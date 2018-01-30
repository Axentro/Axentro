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
    super("POST", "/rpc", HTTP::Headers.new, IO::Memory.new)
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
        sender_wallet = wallet_1
        recipient_wallet = wallet_2

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
          http_res = res.response.unsafe_as(MockResponse).content
          transaction_json = http_res.split("\n")[4].chomp
          transaction = Transaction.from_json(transaction_json)
          transaction.action.should eq("send")
          transaction.prev_hash.should eq("0")
          transaction.message.should eq("")
          transaction.sign_r.should eq("0")
          transaction.sign_s.should eq("0")
          transaction.senders.should eq(senders)
          transaction.recipients.should eq(recipients)
        else
          fail "expected an io response"
        end
      end

      it "should raise an error: invalid fee if fee is too small for action" do
        sender_wallet = wallet_1
        recipient_wallet = wallet_2

        chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
        blockchain = Blockchain.new(sender_wallet)
        blockchain.replace_chain(chain)

        rpc = RPCController.new(blockchain)

        senders = [a_sender(sender_wallet, 0_i64)]
        recipients = [a_recipient(recipient_wallet, 10_i64)]

        payload = {
          call:       "create_unsigned_transaction",
          action:     "send",
          senders:    senders.to_json,
          recipients: recipients.to_json,
          message:    "",
        }.to_json

        json = JSON.parse(payload)

        expect_raises(Exception, "Invalid fee -10 for the action send") do
          rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), nil)
        end
      end
    end

    describe "#create_transaction" do

      it "should return a signed transaction when valid" do
        sender_wallet = wallet_1
        recipient_wallet = wallet_2

        chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
        blockchain = Blockchain.new(sender_wallet)
        blockchain.replace_chain(chain)

        rpc = RPCController.new(blockchain)

        senders = [a_sender(sender_wallet, 1000_i64)]
        recipients = [a_recipient(recipient_wallet, 100_i64)]

        unsigned_transaction = Transaction.new(
          Transaction.create_id,
          "send", # action
          senders,
          recipients,
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        signature = sign(sender_wallet, unsigned_transaction)
        signed_transaction = unsigned_transaction.signed(signature[:r], signature[:s])

        payload = {
          call:        "create_transaction",
          transaction: signed_transaction.to_json,
        }.to_json

        json = JSON.parse(payload)

        res = rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), nil)
        res.response.output.flush
        res.response.output.close
        output = res.response.output
        case output
        when IO
          res.response.status_code.should eq(200)
          http_res = res.response.unsafe_as(MockResponse).content
          transaction_json = http_res.split("\n")[4].chomp
          transaction = Transaction.from_json(transaction_json)
          transaction.action.should eq("send")
          transaction.prev_hash.should eq("0")
          transaction.message.should eq("0")
          transaction.sign_r.should eq(signature[:r])
          transaction.sign_s.should eq(signature[:s])
          transaction.senders.should eq(senders)
          transaction.recipients.should eq(recipients)
        else
          fail "expected an io response"
        end

      end

      it "should return a 403 when an Exception occurs" do
        sender_wallet = wallet_1
        recipient_wallet = wallet_2

        chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
        blockchain = Blockchain.new(sender_wallet)
        blockchain.replace_chain(chain)

        rpc = RPCController.new(blockchain)

        senders = [a_sender(sender_wallet, 1000_i64)]
        recipients = [a_recipient(recipient_wallet, 100_i64)]

        payload = {
          call:    "create_transaction",
          missing: "missing",
        }.to_json

        json = JSON.parse(payload)

        res = rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), nil)
        res.response.output.flush
        res.response.output.close
        output = res.response.output
        case output
        when IO
          res.response.status_code.should eq(403)
          http_res = res.response.unsafe_as(MockResponse).content
          http_res.includes?(%{Missing hash key: "transaction"}).should be_true
        else
          fail "expected an io response"
        end
      end

    end

    describe "#amount" do
      sender_wallet = wallet_1
      chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
      blockchain = Blockchain.new(sender_wallet)
      blockchain.replace_chain(chain)

      rpc = RPCController.new(blockchain)

      payload = {call: "blockchain_size"}.to_json
      json = JSON.parse(payload)

      res = rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), nil)
      res.response.output.flush
      res.response.output.close
      output = res.response.output
      case output
      when IO
        res.response.status_code.should eq(200)
        http_res = res.response.unsafe_as(MockResponse).content
        size = http_res.split("\n")[4].chomp
        size.should eq(%{{"size":1}})
      else
        fail "expected an io response"
      end
    end

  end

    STDERR.puts "< Node::RPCController"
end
