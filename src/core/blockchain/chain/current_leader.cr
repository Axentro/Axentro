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
  struct CurrentLeader
    property address : String
    property node_id : String

    def initialize(@address : String, @node_id : String); end

    def get_address : String
      @address
    end

    def get_node_id : String
      @node_id
    end

    def ==(other : CurrentLeader)
      other.address == @address && other.node_id == @node_id
    end

    def to_s
      "node_id: #{@node_id}, address: #{@address}"
    end
  end
end
