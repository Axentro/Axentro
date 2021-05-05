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

module ::Units::Utils::NodeHelper
  include Axentro::Core

  class MockRequest < HTTP::Request
    def initialize(method : String, url : String = "/rpc", body : IO = IO::Memory.new, headers : HTTP::Headers = HTTP::Headers.new)
      super(method, url, headers, body, "HTTP/1.1", internal: nil)
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
    def initialize(method : String = "POST", url : String = "/rpc", body : IO = IO::Memory.new)
      @request = MockRequest.new(method, url, body).unsafe_as(HTTP::Request)
      @request.path = url
      @response = MockResponse.new.unsafe_as(HTTP::Server::Response)
    end
  end

  def exec_rest_api(res, status_code = 200, &block)
    res.response.output.flush
    res.response.output.close
    output = res.response.output
    case output
    when IO
      res.response.status_code.should eq(status_code)
      http_res = res.response.unsafe_as(MockResponse).content
      begin
        yield JSON.parse(http_res.split("\n").find(&.includes?("result")).not_nil!.chomp)
      rescue e : Exception
        yield JSON.parse(http_res.split("\n").find(&.includes?("status")).not_nil!.chomp)
      end
    else
      fail "expected an io response"
    end
  rescue e : Exception
    fail "something failed: #{e}"
  end

  def with_rpc_exec_internal_post(rpc, json, status_code = 200, &block)
    res = rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), {} of String => String)
    res.response.output.flush
    res.response.output.close
    output = res.response.output
    case output
    when IO
      res.response.status_code.should eq(status_code)
      http_res = res.response.unsafe_as(MockResponse).content
      json_result = JSON.parse(http_res.split("\n")[4].chomp)

      if json_result["status"].as_s == "success"
        # json_result step above does JSON.parse which converts the nonce to i64 instead of u64
        # so this is a quick fix as we hardcode all the nonces in the specs
        yield json_result["result"].to_json.gsub("-6727529038553890404", "11719215035155661212")
      else
        yield json_result["reason"].as_s
      end
    else
      fail "expected an io response"
    end
  rescue e : Exception
    yield e.message.not_nil!
  end

  def with_rpc_exec_internal_get(rpc, status_code = 200, &block)
    res = rpc.exec_internal_get(MockContext.new("GET").unsafe_as(HTTP::Server::Context), {} of String => String)
    res.response.output.flush
    res.response.output.close
    output = res.response.output
    case output
    when IO
      res.response.status_code.should eq(status_code)
      http_res = res.response.unsafe_as(MockResponse).content
      json_result = JSON.parse(http_res.split("\n")[4].chomp)

      if json_result["status"].as_s == "success"
        yield json_result["result"].to_json
      else
        yield json_result["reason"].as_s
      end
    else
      fail "expected an io response"
    end
  rescue e : Exception
    fail "something failed: #{e}"
  end
end
