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

module ::Sushi::Core::BlockQueue
  class TaskFoundNonce < Task
    def initialize(
      @callback : Node,
      @nonce : UInt64,
      @miners : NodeComponents::MinersManager::Miners
    )
    end

    def exec
      if block = queue.blockchain.valid_block?(@nonce, @miners)
        info "found new nonce: #{light_green(@nonce)} (block: #{block.index})"
        @callback.callback(block, true)
      end
    rescue e : Exception
      warning "found nonce #{@nonce} has been rejected for the reason: #{e.message}"

      #
      # todo
      #
      error e.backtrace.not_nil!.join("\n")
    end
  end
end
