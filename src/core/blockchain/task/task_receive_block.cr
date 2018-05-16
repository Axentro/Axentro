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

# module ::Sushi::Core::BlockQueue
#   class TaskReceiveBlock < Task
#     def initialize(@callback : Node, @block : Block)
#     end
#  
#     def exec
#       if block = queue.blockchain.valid_block?(@block)
#         info "received block at #{@block.index} is valid. import the block."
#         @callback.callback(block, false)
#       end
#     rescue e : Exception
#       warning "coming block at #{@block.index} has been rejected for the reason: #{e.message}"
#     end
#   end
# end
