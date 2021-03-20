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

module ::Axentro::Core
  alias MinerWork = NamedTuple(start_nonce: BlockNonce, difficulty: Int32, block: Block)

  class MinerWorker < Tokoroten::Worker
    def task(message : String)
      work = MinerWork.from_json(message)

      block_nonce = work[:start_nonce]
      nonce_counter = 0

      latest_nonce_counter = nonce_counter
      time_now = __timestamp
      latest_time = time_now

      miner_nonce = MinerNonce.from(block_nonce)

      # just initialized so we can re-define it inside the loop each time
      block = work[:block]
      block_hash = ""

      loop do
        time_now = __timestamp

        # update with latest nonce and difficulty
        block = block.with_nonce(block_nonce).with_difficulty(work[:difficulty])
        block_hash = block.to_hash

        if calculate_pow_difficulty(block.mining_version, block_hash, block_nonce, work[:difficulty]) == work[:difficulty]
          miner_nonce = MinerNonce.from(block_nonce).with_difficulty(work[:difficulty]).with_timestamp(time_now)
          break
        end

        nonce_counter += 1
        block_nonce = (block_nonce.to_u64 + 1).to_s

        if nonce_counter % 100 == 0
          time_diff = time_now - latest_time

          break if time_diff == 0

          block_nonce = Random.rand(UInt64::MAX).to_s

          work_rate = (nonce_counter - latest_nonce_counter) / (time_diff / 1000)

          info "#{nonce_counter - latest_nonce_counter} works, #{work_rate_with_unit(work_rate)}"

          latest_nonce_counter = nonce_counter
          latest_time = time_now
        end
      end

      debug "nonce: #{calculate_pow_difficulty(block.mining_version, block_hash, block_nonce, work[:difficulty])}, required: #{work[:difficulty]}, nonce: #{block_nonce}, hash: #{block_hash}"
      info "found new nonce(#{work[:difficulty]}): #{light_green(block_nonce)}"
      debug "Found block..."

      response(miner_nonce.to_json)
    rescue e : Exception
      error e.message.not_nil!
      error e.backtrace.join("\n")
    end

    private def work_rate_with_unit(work_rate : Float64) : String
      return "#{work_rate.to_i} [Work/s]" if work_rate / 1000.0 <= 1.0
      return "#{(work_rate/1000.0).to_i} [KWork/s]" if work_rate / 1000000.0 <= 1.0
      return "#{(work_rate/1000000.0).to_i} [MWork/s]" if work_rate / 1000000000.0 <= 1.0
      "#{(work_rate/1000000000.0).to_i} [GWork/s]"
    end

    include Logger
    include Consensus
    include Common::Color
    include Common::Timestamp
  end

  include NonceModels
end
