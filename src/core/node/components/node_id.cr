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

module ::Axentro::Core::NodeComponents
  class NodeID
    getter id : String

    def self.create_from(id : String)
      NodeID.new(id)
    end

    def initialize(_id : String? = nil)
      @id = if id = _id
              id
            else
              Random::Secure.hex(16)
            end

      @id_num = BigInt.new(@id, base: 16)
    end

    def >(other : NodeID)
      @id_num > BigInt.new(other.id, base: 16)
    end

    def <(other : NodeID)
      @id_num < BigInt.new(other.id, base: 16)
    end

    def >=(other : NodeID)
      @id_num >= BigInt.new(other.id, base: 16)
    end

    def <=(other : NodeID)
      @id_num <= BigInt.new(other.id, base: 16)
    end

    def ==(other : NodeID)
      @id_num == BigInt.new(other.id, base: 16)
    end

    def !=(other : NodeID)
      @id_num != BigInt.new(other.id, base: 16)
    end

    def >(other : String)
      @id_num > BigInt.new(other, base: 16)
    end

    def <(other : String)
      @id_num < BigInt.new(other, base: 16)
    end

    def >=(other : String)
      @id_num >= BigInt.new(other, base: 16)
    end

    def <=(other : String)
      @id_num <= BigInt.new(other, base: 16)
    end

    def ==(other : String)
      @id_num == BigInt.new(other, base: 16)
    end

    def !=(other : String)
      @id_num != BigInt.new(other, base: 16)
    end

    def to_s : String
      @id
    end
  end
end
