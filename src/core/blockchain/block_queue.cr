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
  class BlockQueue
    @queue : Array(Task) = [] of Task
    @processing : Bool = false

    record Task, block : Block

    def initialize(@blockchain)
      
    end

    def enqueue(task : Task)
      @queue << task
    end

    def run
      spawn do
        loop do
          sleep 0.5

          STDERR.puts "BuildQueue main loop ..."

          next if @processing
          next if @queue.empty?

          STDERR.puts "--- next task"

          task = @queue.shift
        end
      end
    end
  end
end
