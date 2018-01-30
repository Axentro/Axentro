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

        chain = [block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
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

        chain = [block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
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

        chain = [block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
        blockchain = Blockchain.new(sender_wallet)
        blockchain.replace_chain(chain)

        rpc = RPCController.new(blockchain)
        node = Node.new(true, true, "bind_host", 8008_i32, nil, nil, nil, nil, sender_wallet, nil, 1_i32)
        rpc.set_node(node)

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

        chain = [block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
        blockchain = Blockchain.new(sender_wallet)
        blockchain.replace_chain(chain)

        rpc = RPCController.new(blockchain)
        node = Node.new(true, true, "bind_host", 8008_i32, nil, nil, nil, nil, sender_wallet, nil, 1_i32)
        rpc.set_node(node)

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

      it "should return the blockchain size for the current node" do
        sender_wallet = wallet_1
        chain = [block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
        blockchain = Blockchain.new(sender_wallet)
        blockchain.replace_chain(chain)

        rpc = RPCController.new(blockchain)
        node = Node.new(true, true, "bind_host", 8008_i32, nil, nil, nil, nil, sender_wallet, nil, 1_i32)
        rpc.set_node(node)

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
          size.should eq(%{{"size":11}})
        else
          fail "expected an io response"
        end
      end
    end

    describe "#blockchain" do

      it "should return the full blockchain including headers" do
        sender_wallet = wallet_1
        chain = [block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
        blockchain = Blockchain.new(sender_wallet)
        blockchain.replace_chain(chain)

        rpc = RPCController.new(blockchain)
        node = Node.new(true, true, "bind_host", 8008_i32, nil, nil, nil, nil, sender_wallet, nil, 1_i32)
        rpc.set_node(node)

        payload = {call: "blockchain", header: false}.to_json
        json = JSON.parse(payload)

        res = rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), nil)
        res.response.output.flush
        res.response.output.close
        output = res.response.output
        case output
        when IO
          res.response.status_code.should eq(200)
          http_res = res.response.unsafe_as(MockResponse).content
          full_blockchain = http_res.split("\n")[4].chomp
          full_blockchain.should eq(expected_blockchain)
        else
          fail "expected an io response"
        end
      end

     it "should return the blockchain headers only" do
       sender_wallet = wallet_1
       chain = [block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
       blockchain = Blockchain.new(sender_wallet)
       blockchain.replace_chain(chain)

       rpc = RPCController.new(blockchain)
       node = Node.new(true, true, "bind_host", 8008_i32, nil, nil, nil, nil, sender_wallet, nil, 1_i32)
       rpc.set_node(node)

       payload = {call: "blockchain", header: true}.to_json
       json = JSON.parse(payload)

       res = rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), nil)
       res.response.output.flush
       res.response.output.close
       output = res.response.output
       case output
       when IO
         res.response.status_code.should eq(200)
         http_res = res.response.unsafe_as(MockResponse).content
         headers = http_res.split("\n")[4].chomp
         headers.should eq(expected_headers)
       else
         fail "expected an io response"
       end
     end
    end

  end

    STDERR.puts "< Node::RPCController"
end

def expected_headers
  %{[{"index":0,"nonce":0,"prev_hash":"genesis","merkle_tree_root":""},{"index":1,"nonce":9837448705800144284,"prev_hash":"5396e18efa80a8e891c417fff862d7cad171465e65bc4b4e5e1c1c3ab0aeb88f","merkle_tree_root":"3f38bc1555ee54f7287e099e58ec699764035036"},{"index":2,"nonce":4531115808962198085,"prev_hash":"7cbc286a6db06aa97ba57f3f39bf06586c2f18cfcc6495023d5cdd012abeec60","merkle_tree_root":"c96d6d7d9cb53a61316dfac05b913d61a3ec02c4"},{"index":3,"nonce":12703492358992392334,"prev_hash":"c02f8c2473d70974cecae25d8ed647ecd190fbc65974ec028d9bd5c67b9228b3","merkle_tree_root":"a68238e91020663ef12e915e7ed7483e292f63cb"},{"index":4,"nonce":5858896090230544209,"prev_hash":"161aa54e783b5912cedbff435f281dad7706c14fd4da8053687a20b89e308983","merkle_tree_root":"efc19e65518848efce6cde777bfe788912fba5e0"},{"index":5,"nonce":4405480561502108575,"prev_hash":"f810b0e2292554fb7cdbd8cadf54847ab7db261139fcc7e52b7ef73cc12ea8b9","merkle_tree_root":"8149f94bf7e4a07013c795210e480f120e1c334d"},{"index":6,"nonce":7413164795613819364,"prev_hash":"68c44f4fc667fe8f1682291be86b1a88265973e984c72f726cac37c137d1e8de","merkle_tree_root":"ed1f501abcb34b728182c8269b1da18638af162a"},{"index":7,"nonce":10747415878307008285,"prev_hash":"83a7ad0edeaa2ece2b9ec8367eaa9321e334f047af3f44b111df261259712acc","merkle_tree_root":"5a7f3da9b34f280417a7fa38e32dbab66fdd2143"},{"index":8,"nonce":429911461262732095,"prev_hash":"7a81a9b75959dbacbebc8e04995645ca6e779a8221980691290aff045b1e3c20","merkle_tree_root":"2ae5132493c63d255e750f6c2311069ec5f1c1fb"},{"index":9,"nonce":10090336744143692275,"prev_hash":"6bbbb325eee060b31d0868b6e5a5675882357250ccbde66e84c979e90f55dab0","merkle_tree_root":"a3fe3cf077a54a3c9dcea9df634bad0ef8eaa1e7"},{"index":10,"nonce":2651254945948760122,"prev_hash":"5e4912e0aa29d8f5ea624949fe3ff6fd95903b13f77d71425a87782e603fd9f8","merkle_tree_root":"127a0a1531fc66942b0f7e079be7992694606c4f"}]}
end

def expected_blockchain
  %{[{"index":0,"transactions":[],"nonce":0,"prev_hash":"genesis","merkle_tree_root":""},{"index":1,"transactions":[{"id":"f804d856480e6a5fc2a9df77c2f761814e6ac63b722386c2d04a1d2b52a9e069","action":"head","senders":[],"recipients":[{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":10000}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":9837448705800144284,"prev_hash":"5396e18efa80a8e891c417fff862d7cad171465e65bc4b4e5e1c1c3ab0aeb88f","merkle_tree_root":"3f38bc1555ee54f7287e099e58ec699764035036"},{"index":2,"transactions":[{"id":"73478665802282437a537a72985befb106d3864e10ca43bab44ee96406256586","action":"head","senders":[],"recipients":[{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":2500},{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":4531115808962198085,"prev_hash":"7cbc286a6db06aa97ba57f3f39bf06586c2f18cfcc6495023d5cdd012abeec60","merkle_tree_root":"c96d6d7d9cb53a61316dfac05b913d61a3ec02c4"},{"index":3,"transactions":[{"id":"040d18deb79d43008b8ef881582f39973b91d182c8fd6c7912d66405b2e3eee7","action":"head","senders":[],"recipients":[{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":2500},{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":12703492358992392334,"prev_hash":"c02f8c2473d70974cecae25d8ed647ecd190fbc65974ec028d9bd5c67b9228b3","merkle_tree_root":"a68238e91020663ef12e915e7ed7483e292f63cb"},{"index":4,"transactions":[{"id":"d0dfea3efeaf7921a6fc88ddcddb7969a74233d70bd4f322940929ad31ed776d","action":"head","senders":[],"recipients":[{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":10000}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":5858896090230544209,"prev_hash":"161aa54e783b5912cedbff435f281dad7706c14fd4da8053687a20b89e308983","merkle_tree_root":"efc19e65518848efce6cde777bfe788912fba5e0"},{"index":5,"transactions":[{"id":"60653b3db09cfa3f0cd344b98c63b7b7e4191d3202b94338db80525362dc9f09","action":"head","senders":[],"recipients":[{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":2500},{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":4405480561502108575,"prev_hash":"f810b0e2292554fb7cdbd8cadf54847ab7db261139fcc7e52b7ef73cc12ea8b9","merkle_tree_root":"8149f94bf7e4a07013c795210e480f120e1c334d"},{"index":6,"transactions":[{"id":"d1775fc5124f24921248f847161d166cfeb16c0b5c6e5317770fe8c008d61470","action":"head","senders":[],"recipients":[{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":2500},{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":7413164795613819364,"prev_hash":"68c44f4fc667fe8f1682291be86b1a88265973e984c72f726cac37c137d1e8de","merkle_tree_root":"ed1f501abcb34b728182c8269b1da18638af162a"},{"index":7,"transactions":[{"id":"6372433f05ee2892819e5985374690a46f0b9e53cd78e106da89868200082ecf","action":"head","senders":[],"recipients":[{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":2500},{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":10747415878307008285,"prev_hash":"83a7ad0edeaa2ece2b9ec8367eaa9321e334f047af3f44b111df261259712acc","merkle_tree_root":"5a7f3da9b34f280417a7fa38e32dbab66fdd2143"},{"index":8,"transactions":[{"id":"eae201f21f5a87a993c6e63b76dd67952e614bbb1a3e11edf3a4a87d3833a178","action":"head","senders":[],"recipients":[{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":2500},{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":429911461262732095,"prev_hash":"7a81a9b75959dbacbebc8e04995645ca6e779a8221980691290aff045b1e3c20","merkle_tree_root":"2ae5132493c63d255e750f6c2311069ec5f1c1fb"},{"index":9,"transactions":[{"id":"e973eec50de293afa387512b5b48c2caaa30ca4112fb06d61ffc15d787db4156","action":"head","senders":[],"recipients":[{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":2500},{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":10090336744143692275,"prev_hash":"6bbbb325eee060b31d0868b6e5a5675882357250ccbde66e84c979e90f55dab0","merkle_tree_root":"a3fe3cf077a54a3c9dcea9df634bad0ef8eaa1e7"},{"index":10,"transactions":[{"id":"74c1327450701bf33bb3af8bce3958f792772a5b9af88074efabb7e396230290","action":"head","senders":[],"recipients":[{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":2500},{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":2651254945948760122,"prev_hash":"5e4912e0aa29d8f5ea624949fe3ff6fd95903b13f77d71425a87782e603fd9f8","merkle_tree_root":"127a0a1531fc66942b0f7e079be7992694606c4f"}]}
end
