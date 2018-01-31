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

end
