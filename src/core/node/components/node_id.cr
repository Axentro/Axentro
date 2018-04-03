module ::Sushi::Core::NodeComponents
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

    def to_s : String
      @id
    end
  end
end
