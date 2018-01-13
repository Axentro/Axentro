module ::Sushi::Core::ECDSA
  class Point
    getter x : BigInt
    getter y : BigInt

    def initialize(@group : Group, @x : BigInt, @y : BigInt, @infinity : Bool = false)
    end

    def mod : BigInt
      @group._p
    end

    def _a
      @group._a
    end

    def _b
      @group._b
    end

    def +(other : Point) : Point
      return other if infinity?
      return self if other.infinity?

      lamda = ((other.y - @y) * mod_inv(other.x - @x, mod)) % mod
      x = (lamda ** 2 - @x - other.x) % mod
      y = (lamda * (@x - x) - @y) % mod

      return Point.new(@group, x, y)
    end

    def double : Point
      return self if infinity?

      lamda = ((3 * (@x ** 2) + _a) * mod_inv(2 * @y, mod)) % mod
      x = (lamda ** 2 - 2 * @x) % mod
      y = (lamda * (@x - x) - @y) % mod

      Point.new(@group, x, y)
    end

    def *(other : BigInt) : Point
      res = @group.infinity
      v = self

      while other > 0
        res = res + v if other.odd?
        v = v.double
        other >>= 1
      end

      res
    end

    def is_on? : Bool
      (@y ** 2 - @x ** 3 - _b) % mod == 0
    end

    def infinity? : Bool
      @infinity
    end

    include ECDSA
  end
end
