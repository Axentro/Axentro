#
# An example for SushiChain's dApps
#
# - Hello World!
#
#   It just show a message "Hello world! from SushiChain :)"
#   Execute following command
#   ```
#   curl -XPOST http://[your node]/rpc -d "{\"call\": \"hello\"}"
#   ```
#
module ::Sushi::Core::DApps::User
  class HelloWorld < DApp
    def setup
    end

    def actions : Array(String)
      [] of String
    end

    def related?(action : String) : Bool
      false
    end

    def valid_impl?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
      true
    end

    def record(chain : Models::Chain)
    end

    def clear
    end

    def rpc?(call, json, context, params)
      case call
      when "hello"
        return hello_world(json, context, params)
      end

      nil
    end

    def hello_world(json, context, params)
      context.response.print "Hello world! from SushiChain :)"
      context
    end
  end
end
