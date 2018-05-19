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
  alias MinerWork = NamedTuple(difficulty: Int32, index: Int64, hash: String)

  class MinerWorker < Tokoroten::Worker
    def task(message : String)
      nonce : UInt64 = Random.rand(UInt64::MAX)

      latest_nonce = nonce
      latest_time = Time.now

      work = MinerWork.from_json(message)

      loop do
        break if valid?(work[:index], work[:hash], nonce, work[:difficulty])

        nonce += 1

        if nonce % 100 == 0
          time_now = Time.now
          time_diff = (time_now - latest_time).total_seconds

          break if time_diff == 0

          work_rate = (nonce - latest_nonce) / time_diff

          info "#{nonce - latest_nonce} works, #{work_rate_with_unit(work_rate)}"

          latest_nonce = nonce
          latest_time = time_now
        end
      end

      info "found new nonce(#{work[:difficulty]}): #{light_green(nonce)})"

      response(nonce.to_s)
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
  end
end
