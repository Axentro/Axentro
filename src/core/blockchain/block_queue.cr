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
  #
  # todo
  # remove the queue
  #
  class Queue
    @@block_queue : Queue?

    def self.create_instance(blockchain : Blockchain) : Queue
      @@block_queue ||= Queue.new(blockchain)
      @@block_queue.not_nil!.run
      @@block_queue.not_nil!
    end

    def self.get_instance : Queue
      @@block_queue.not_nil!
    end

    getter blockchain : Blockchain

    @queue : Array(Task) = [] of Task
    @processing : Bool = false

    def initialize(@blockchain : Blockchain)
    end

    def enqueue(task : Task)
      @queue << task
    end

    def run
      spawn do
        loop do
          sleep 0.5

          next if @processing
          next if @queue.empty?

          @queue.shift.exec
        end
      end
    end
  end
end
