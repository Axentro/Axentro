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

require "./../../spec_helper"
require "./../utils"

include Sushi::Core
include Units::Utils
include Sushi::Core::Controllers
include Sushi::Core::Keys

describe RESTController do
  describe "__v1_blockchain" do
    it "should return the full blockchain" do
      with_factory do |block_factory, transaction_factory|
        block_factory.addBlocks(2)
        exec_rest_api(block_factory.rest.__v1_blockchain(context("/api/v1/blockchain"), no_params)) do |result|
           p result
        end
      end
    end
  end
end

def context(url : String)
  MockContext.new(url).unsafe_as(HTTP::Server::Context)
end

def no_params
 {} of String => String
end
