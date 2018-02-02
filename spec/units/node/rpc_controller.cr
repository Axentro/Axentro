require "./../../spec_helper"
require "./../utils"

include Sushi::Core
include Units::Utils
include Sushi::Core::Models
include Sushi::Core::Controllers

describe RPCController do
  describe "#exec_internal_post" do
    describe "#create_unsigned_transaction" do
      it "should return the transaction as json when valid" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
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

          with_rpc_exec_internal_post(rpc, json) do |json_result|
            transaction = Transaction.from_json(json_result)
            transaction.action.should eq("send")
            transaction.prev_hash.should eq("0")
            transaction.message.should eq("")
            transaction.sign_r.should eq("0")
            transaction.sign_s.should eq("0")
            transaction.senders.should eq(senders)
            transaction.recipients.should eq(recipients)
          end
        end
      end

      it "should raise an error: invalid fee if fee is too small for action" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
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
    end

    describe "#create_transaction" do
      it "should return a signed transaction when valid" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
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

          with_rpc_exec_internal_post(rpc, json) do |json_result|
            transaction = Transaction.from_json(json_result)
            transaction.action.should eq("send")
            transaction.prev_hash.should eq("0")
            transaction.message.should eq("0")
            transaction.sign_r.should eq(signature[:r])
            transaction.sign_s.should eq(signature[:s])
            transaction.senders.should eq(senders)
          end
        end
      end

      it "should return a 403 when an Exception occurs" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          senders = [a_sender(sender_wallet, 1000_i64)]
          recipients = [a_recipient(recipient_wallet, 100_i64)]

          payload = {
            call:    "create_transaction",
            missing: "missing",
          }.to_json

          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json, 403) do |res|
            res.includes?(%{Missing hash key: "transaction"}).should be_true
          end
        end
      end
    end

    describe "#blockchain_size" do
      it "should return the blockchain size for the current node" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "blockchain_size"}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |json_result|
            json_result.should eq(%{{"size":11}})
          end
        end
      end
    end

    describe "#blockchain" do
      it "should return the full blockchain including headers" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "blockchain", header: false}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |json_result|
            json_result.should eq(expected_blockchain)
          end
        end
      end

      it "should return the blockchain headers only" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "blockchain", header: true}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |json_result|
            json_result.should eq(expected_headers)
          end
        end
      end
    end

    describe "#amount" do
      it "should return the unconfirmed amount" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          recipient_address = block_1.transactions.first.recipients.first[:address]
          payload = {call: "amount", address: recipient_address, unconfirmed: true}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |json_result|
            json_result.should eq(%{{"amount":32500,"address":"#{recipient_address}","unconfirmed":true}})
          end
        end
      end

      it "should return the confirmed amount" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          recipient_address = block_1.transactions.first.recipients.first[:address]
          payload = {call: "amount", address: recipient_address, unconfirmed: false}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |json_result|
            json_result.should eq(%{{"amount":10000,"address":"#{recipient_address}","unconfirmed":false}})
          end
        end
      end
    end

    describe "#transactions" do
      it "should return transactions for the specified block index" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "transactions", index: 1}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |json_result|
            json_result.should eq(expected_transactions)
          end
        end
      end

      it "should raise an error: invalid index" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "transactions", index: 99}.to_json
          json = JSON.parse(payload)

          expect_raises(Exception, "Invalid index 99 (Blockchain size is 11)") do
            rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), nil)
          end
        end
      end
    end

    describe "#transaction" do
      it "should return a transaction for the supplied transaction id" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "transaction", transaction_id: block_2.transactions.first.id}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |json_result|
            json_result.should eq(expected_transaction)
          end
        end
      end

      it "should raise an error: transaction not found in any block" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "transaction", transaction_id: "invalid-transaction-id"}.to_json
          json = JSON.parse(payload)

          expect_raises(Exception, "Failed to find a block for the transaction invalid-transaction-id") do
            rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), nil)
          end
        end
      end

      # TODO - Kings - Not sure how to make this error
      pending "should raise an error: transaction not found for supplied transaction id" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "transaction", transaction_id: "invalid-transaction-id"}.to_json
          json = JSON.parse(payload)

          expect_raises(Exception, "Failed to find a block for the transaction invalid-transaction-id") do
            rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), nil)
          end
        end
      end
    end

    describe "#block" do
      it "should return the block specified by the supplied block index" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "block", index: 2, header: false}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |json_result|
            json_result.should eq(expected_block)
          end
        end
      end

      it "should return the block header specified by the supplied block index" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "block", index: 2, header: true}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |json_result|
            json_result.should eq(expected_block_header)
          end
        end
      end

      it "should return the block specified by the supplied transaction id" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "block", transaction_id: block_2.transactions.first.id, header: false}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |json_result|
            json_result.should eq(expected_block)
          end
        end
      end

      it "should return the block header specified by the supplied transaction id" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "block", transaction_id: block_2.transactions.first.id, header: true}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |json_result|
            json_result.should eq(expected_block_header)
          end
        end
      end

      it "should raise a error: invalid index" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "block", index: 99, header: false}.to_json
          json = JSON.parse(payload)

          expect_raises(Exception, "Invalid index 99 (Blockchain size is 11)") do
            rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), nil)
          end
        end
      end

      it "should raise an error: failed to find a block for the transaction" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "block", transaction_id: "invalid-transaction-id", header: false}.to_json
          json = JSON.parse(payload)

          expect_raises(Exception, "Failed to find a block for the transaction invalid-transaction-id") do
            rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), nil)
          end
        end
      end
    end

    describe "#unpermitted_call" do
      it "should raise an error: Missing hash key call" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {unknown: "unknown"}.to_json
          json = JSON.parse(payload)

          expect_raises(Exception, %{Missing hash key: "call"}) do
            rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), nil)
          end
        end
      end

      it "should return a 403 when the rpc call is unknown" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "unknown"}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json, 403) do |json_result|
            json_result.should eq("Unpermitted call: unknown")
          end
        end
      end
    end
  end

  describe "#exec_internal_get" do
    it "should return an unpermitted call response" do
      with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
        payload = {call: "unknown"}.to_json
        json = JSON.parse(payload)

        with_rpc_exec_internal_get(rpc, 403) do |json_result|
          json_result.should eq("Unpermitted method: GET")
        end
      end
    end
  end

  STDERR.puts "< Node::RPCController"
end

def expected_headers
  %{[{"index":0,"nonce":0,"prev_hash":"genesis","merkle_tree_root":""},{"index":1,"nonce":2904846426898123243,"prev_hash":"5396e18efa80a8e891c417fff862d7cad171465e65bc4b4e5e1c1c3ab0aeb88f","merkle_tree_root":"bc5611dd1c13ee3fe971ebb6ae7776ceae404754"},{"index":2,"nonce":15503140033762618189,"prev_hash":"8ee860f9b3349905085e1b49acaff7f76bc2ce08a109ece1f3f2f0acf3b91255","merkle_tree_root":"7d1136d20c414b816557cffdb3b05622263d035a"},{"index":3,"nonce":11577508140005022087,"prev_hash":"740aa29e17f2bbb6793a54b6ad1322f234d3297054521fb68406770fdce9ae16","merkle_tree_root":"9941fbaa8b7d7a63ef961cbffc6c4d23372e40c2"},{"index":4,"nonce":2152713874635269483,"prev_hash":"f2b077540d751dd25fdd3682d118f4d190c4da2072e08e9fcce448ffd47fc4f3","merkle_tree_root":"fcaf9df3f1d6517418518bd927299e647754623e"},{"index":5,"nonce":15024682274700691373,"prev_hash":"393dfb99353c5c0a5cb85489af5946a7176227f7e4b78bc9a163adbadc41e88b","merkle_tree_root":"0eec5fa02f766cbdd6b03e91769a597102aa6f85"},{"index":6,"nonce":1169291176586852846,"prev_hash":"6e9d6c496d75345fd8e3904e08273107c75e800c8e600824e21c08c089d97715","merkle_tree_root":"b7383c24ec17309841a15cbb65e5f7210a17b3b1"},{"index":7,"nonce":40660323347632100,"prev_hash":"dc143454bc0cc303f6a615d8158ed229fc75375ce35d5d918ca2747778ea07bd","merkle_tree_root":"0bfed704976ff9e53a3dc20e6ea4b5adbda52998"},{"index":8,"nonce":17345917019112288963,"prev_hash":"3845af0536f19acda092af964568c0d45e5035f33fed9a524ecbf101e8fc03d4","merkle_tree_root":"3b36d207ef0243c34ce89880a87276d0816e2d5d"},{"index":9,"nonce":1046000349784630844,"prev_hash":"fd3c97d8780cd4ce5cdf53a0b4637721a90dcdd4d74d5ec312cd09f81e512647","merkle_tree_root":"f33eabbcd7f0f109e67bcf8a686a7b4af6838654"},{"index":10,"nonce":8523480423442361452,"prev_hash":"0ea46301b8109fc50094f8ffe020f1b98ab8edc515cbe1416b7d4d33e75392f8","merkle_tree_root":"fb413020daac2b6b55b0ce8be73da129fcd41880"}]}
end

def expected_blockchain
  %{[{"index":0,"transactions":[],"nonce":0,"prev_hash":"genesis","merkle_tree_root":""},{"index":1,"transactions":[{"id":"612dded4b67f31ef5a0bc89a2f045fea5f247b3d42fbc3fee46a5af43e5bd62e","action":"head","senders":[],"recipients":[{"address":"VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl","amount":10000}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":2904846426898123243,"prev_hash":"5396e18efa80a8e891c417fff862d7cad171465e65bc4b4e5e1c1c3ab0aeb88f","merkle_tree_root":"bc5611dd1c13ee3fe971ebb6ae7776ceae404754"},{"index":2,"transactions":[{"id":"58a46001b5568a88fc2ea09ab15571ddfa1b8458f638c1c74ff4d7ee652d556d","action":"head","senders":[],"recipients":[{"address":"VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl","amount":2500},{"address":"VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":15503140033762618189,"prev_hash":"8ee860f9b3349905085e1b49acaff7f76bc2ce08a109ece1f3f2f0acf3b91255","merkle_tree_root":"7d1136d20c414b816557cffdb3b05622263d035a"},{"index":3,"transactions":[{"id":"ff41df01e3d8db88b9728e6ebaece3010397015e1422cd36adbb46dcfb050c9f","action":"head","senders":[],"recipients":[{"address":"VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl","amount":2500},{"address":"VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":11577508140005022087,"prev_hash":"740aa29e17f2bbb6793a54b6ad1322f234d3297054521fb68406770fdce9ae16","merkle_tree_root":"9941fbaa8b7d7a63ef961cbffc6c4d23372e40c2"},{"index":4,"transactions":[{"id":"36ebd7571c617cecb49235c8367a59f449c34a20ec4235c31ac46dcc7a8836df","action":"head","senders":[],"recipients":[{"address":"VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl","amount":2500},{"address":"VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":2152713874635269483,"prev_hash":"f2b077540d751dd25fdd3682d118f4d190c4da2072e08e9fcce448ffd47fc4f3","merkle_tree_root":"fcaf9df3f1d6517418518bd927299e647754623e"},{"index":5,"transactions":[{"id":"c194bac1e5b61584886435f29275c69dfce2d2f70008a429015e181310d4b82f","action":"head","senders":[],"recipients":[{"address":"VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl","amount":2500},{"address":"VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":15024682274700691373,"prev_hash":"393dfb99353c5c0a5cb85489af5946a7176227f7e4b78bc9a163adbadc41e88b","merkle_tree_root":"0eec5fa02f766cbdd6b03e91769a597102aa6f85"},{"index":6,"transactions":[{"id":"368fc7235ddb090ba5c274c6e5e391a662b2f198b73906f0ee7e4dbbc15b2180","action":"head","senders":[],"recipients":[{"address":"VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl","amount":2500},{"address":"VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":1169291176586852846,"prev_hash":"6e9d6c496d75345fd8e3904e08273107c75e800c8e600824e21c08c089d97715","merkle_tree_root":"b7383c24ec17309841a15cbb65e5f7210a17b3b1"},{"index":7,"transactions":[{"id":"d9f478abd647dc836aa6f54818b7b05719e0f824b8d8904bba8702cfce9e51e8","action":"head","senders":[],"recipients":[{"address":"VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl","amount":2500},{"address":"VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":40660323347632100,"prev_hash":"dc143454bc0cc303f6a615d8158ed229fc75375ce35d5d918ca2747778ea07bd","merkle_tree_root":"0bfed704976ff9e53a3dc20e6ea4b5adbda52998"},{"index":8,"transactions":[{"id":"60ad1a87d5dd5490554c6cee20997074263d40ff716be8c469748b219278ba71","action":"head","senders":[],"recipients":[{"address":"VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl","amount":2500},{"address":"VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":17345917019112288963,"prev_hash":"3845af0536f19acda092af964568c0d45e5035f33fed9a524ecbf101e8fc03d4","merkle_tree_root":"3b36d207ef0243c34ce89880a87276d0816e2d5d"},{"index":9,"transactions":[{"id":"8d555a5473e692ac9c530df64762d230a65f8be92c408a2c02978e46ceb5aa9b","action":"head","senders":[],"recipients":[{"address":"VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl","amount":2500},{"address":"VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":1046000349784630844,"prev_hash":"fd3c97d8780cd4ce5cdf53a0b4637721a90dcdd4d74d5ec312cd09f81e512647","merkle_tree_root":"f33eabbcd7f0f109e67bcf8a686a7b4af6838654"},{"index":10,"transactions":[{"id":"83cf0322ead6593c94748ac129c4c5bbde27a5578c204af97b21e0a59bf10ae2","action":"head","senders":[],"recipients":[{"address":"VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl","amount":2500},{"address":"VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":8523480423442361452,"prev_hash":"0ea46301b8109fc50094f8ffe020f1b98ab8edc515cbe1416b7d4d33e75392f8","merkle_tree_root":"fb413020daac2b6b55b0ce8be73da129fcd41880"}]}
end

def expected_transactions
  %{[{"id":"612dded4b67f31ef5a0bc89a2f045fea5f247b3d42fbc3fee46a5af43e5bd62e","action":"head","senders":[],"recipients":[{"address":"VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl","amount":10000}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}]}
end

def expected_transaction
  %{{"id":"58a46001b5568a88fc2ea09ab15571ddfa1b8458f638c1c74ff4d7ee652d556d","action":"head","senders":[],"recipients":[{"address":"VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl","amount":2500},{"address":"VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}}
end

def expected_block
  %{{"index":2,"transactions":[{"id":"58a46001b5568a88fc2ea09ab15571ddfa1b8458f638c1c74ff4d7ee652d556d","action":"head","senders":[],"recipients":[{"address":"VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl","amount":2500},{"address":"VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":15503140033762618189,"prev_hash":"8ee860f9b3349905085e1b49acaff7f76bc2ce08a109ece1f3f2f0acf3b91255","merkle_tree_root":"7d1136d20c414b816557cffdb3b05622263d035a"}}
end

def expected_block_header
  %{{"index":2,"nonce":15503140033762618189,"prev_hash":"8ee860f9b3349905085e1b49acaff7f76bc2ce08a109ece1f3f2f0acf3b91255","merkle_tree_root":"7d1136d20c414b816557cffdb3b05622263d035a"}}
end
