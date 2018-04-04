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

module ::Units::Utils::NodeHelper
  include Sushi::Core

  class MockRequest < HTTP::Request
    def initialize(method : String)
      super(method, "/rpc", HTTP::Headers.new, IO::Memory.new)
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
    def initialize(method : String = "POST")
      @request = MockRequest.new(method).unsafe_as(HTTP::Request)
      @response = MockResponse.new.unsafe_as(HTTP::Server::Response)
    end
  end

  def blockchain_node(wallet : Wallet) : Blockchain
    blockchain = Blockchain.new(wallet)
    node = Sushi::Core::Node.new(true, true, "bind_host", 8008_i32, nil, nil, nil, nil, nil, wallet, nil, 1_i32, false)
    blockchain.setup(node)
    blockchain
  end

  def with_node(&block)
    sender_wallet = wallet_1
    recipient_wallet = wallet_2

    chain = [block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
    blockchain = Blockchain.new(sender_wallet)
    blockchain.replace_chain(chain)

    rpc = RPCController.new(blockchain)
    node = Sushi::Core::Node.new(true, true, "bind_host", 8008_i32, nil, nil, nil, nil, nil, sender_wallet, nil, 1_i32, false)
    rpc.set_node(node)
    yield sender_wallet, recipient_wallet, chain, blockchain, rpc
  end

  def with_rpc_exec_internal_post(rpc, json, status_code = 200, &block)
    res = rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), nil)
    res.response.output.flush
    res.response.output.close
    output = res.response.output
    case output
    when IO
      res.response.status_code.should eq(status_code)
      http_res = res.response.unsafe_as(MockResponse).content
      json_result = http_res.split("\n")[4].chomp
      yield json_result
    else
      fail "expected an io response"
    end
  end

  def with_rpc_exec_internal_get(rpc, status_code = 200, &block)
    res = rpc.exec_internal_get(MockContext.new("GET").unsafe_as(HTTP::Server::Context), nil)
    res.response.output.flush
    res.response.output.close
    output = res.response.output
    case output
    when IO
      res.response.status_code.should eq(status_code)
      http_res = res.response.unsafe_as(MockResponse).content
      json_result = http_res.split("\n")[4].chomp
      yield json_result
    else
      fail "expected an io response"
    end
  end
end
