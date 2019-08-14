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
  abstract class Block
    extend Hashes

    def to_hash : String
      string = self.to_json
      sha256(string)
    end

    def calculate_merkle_tree_root : String
      return "" if @transactions.size == 0

      current_hashes = @transactions.map { |tx| tx.to_hash }

      loop do
        tmp_hashes = [] of String

        (current_hashes.size / 2).times do |i|
          tmp_hashes.push(sha256(current_hashes[i*2] + current_hashes[i*2 + 1]))
        end

        tmp_hashes.push(current_hashes[-1]) if current_hashes.size % 2 == 1

        current_hashes = tmp_hashes
        break if current_hashes.size == 1
      end

      ripemd160(current_hashes[0])
    end

    def valid?(blockchain : Blockchain, skip_transactions : Bool = false) : Bool
      return valid_as_latest?(blockchain, skip_transactions) unless @index == 0
      valid_as_genesis?
    end

    include Hashes
    include Logger
    include Protocol
    include Consensus
    include Common::Timestamp
  end
end
