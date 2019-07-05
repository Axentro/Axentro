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
  alias MinerWork = NamedTuple(start_nonce: UInt64, difficulty: Int32, block: Block)

  class MinerWorker < Tokoroten::Worker
    def task(message : String)
      work = MinerWork.from_json(message)

      nonce = work[:start_nonce]
      nonce_counter = 0

      latest_nonce_counter = nonce_counter
      time_now = __timestamp
      latest_time = time_now
      start_time = time_now
      block = work[:block].with_nonce(nonce)

      loop do
        time_now = __timestamp
        block = work[:block].with_nonce_and_mined_timestamp(nonce, time_now)
        break if valid_nonce?(block.to_hash, nonce, work[:difficulty]) == work[:difficulty]

        nonce_counter += 1
        nonce += 1

        if nonce_counter % 100 == 0
          time_diff = time_now - latest_time

          break if time_diff == 0

          nonce = Random.rand(UInt64::MAX)

          work_rate = (nonce_counter - latest_nonce_counter) / time_diff.to_f64

          info "#{nonce_counter - latest_nonce_counter} works, #{work_rate_with_unit(work_rate)}"

          latest_nonce_counter = nonce_counter
          latest_time = time_now
        end
      end

      debug "found new nonce(#{work[:difficulty]}): #{light_green(nonce)}"
      debug "Found block..."
      block.to_s

      response({nonce: nonce, timestamp: time_now}.to_json)
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
end
