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

module ::Sushi::Core
  # class ApiDocumentationHandler < HTTP::StaticFileHandler
  #   def initialize(@path : String, public_dir : String, fallthrough = true)
  #     super(public_dir, fallthrough)
  #   end
  #
  #   def call(context : HTTP::Server::Context)
  #     super(context)
  #   end
  # end
  # class ApiDocumentationHandler < HTTP::StaticFileHandler
  class ApiDocumentationHandler
    include HTTP::Handler

    def initialize(@path : String, @filename : String)
    end

    def call(context)
      if context.request.path.try &.starts_with?(@path)
         context.response.headers["Content-Type"] = "text/html"
         context.response << File.read(@filename)
      else
        call_next(context)
      end
    end

    def request_path(path : String) : String
      path[@path.size..-1]
    end
  end

  # class ApiDocumentationHandler < HTTP::StaticFileHandler
  #   def initialize(@path : String, public_dir : String, fallthrough = true)
  #     super(public_dir, fallthrough)
  #   end
  #
  #   def call(context)
  #     if context.request.path.try &.starts_with?(@path)
  #       super
  #     else
  #       call_next(context)
  #     end
  #   end
  #
  #   def request_path(path : String) : String
  #     path[@path.size..-1]
  #   end
  # end
end
