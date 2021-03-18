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
  class MerkleTreeCalculator
    def initialize(@hash_version : HashVersion); end

    def calculate_merkle_tree_root(transactions : Array(Transaction)) : String
      current_hashes = transactions.map { |tx| tx.to_hash }
      _calculate_merkle_tree_root(current_hashes)
    end

    private def _calculate_merkle_tree_root(current_hashes : Array(String)) : String
      return "" if current_hashes.size == 0

      loop do
        tmp_hashes = [] of String

        (current_hashes.size / 2).to_i.times do |i|
          tmp_hashes.push(apply_merkle_hash_version(current_hashes[i*2] + current_hashes[i*2 + 1]))
        end

        tmp_hashes.push(current_hashes[-1]) if current_hashes.size % 2 == 1

        current_hashes = tmp_hashes
        break if current_hashes.size == 1
      end

      ripemd160(current_hashes[0])
    end

    private def apply_merkle_hash_version(hash)
      if @hash_version == HashVersion::V2
        argon2(hash)
      else
        sha256(hash)
      end
    end
  end
end
