module ::Garnet::Core
  class UTXO

    CONFIRMATION = 2

    @utxo_internal : Array(Hash(String, Float64))

    def initialize
      @utxo_internal = Array(Hash(String, Float64)).new
    end

    def get(address : String) : Float64
      return 0.0 if @utxo_internal.size <= CONFIRMATION

      @utxo_internal.reverse[0..-(CONFIRMATION+1)].each do |utxo_internal|
        return utxo_internal[address] if utxo_internal[address]?
      end

      0.0
    end

    def get_unconfirmed(address : String) : Float64
      return 0.0 if @utxo_internal.size == 0

      @utxo_internal.reverse.each do |utxo_internal|
        return utxo_internal[address] if utxo_internal[address]?
      end

      0.0
    end

    def record(chain : Models::Chain)
      return if @utxo_internal.size >= chain.size

      chain[@utxo_internal.size .. -1].each do |block|

        @utxo_internal.push(Hash(String, Float64).new)

        block_utxo = block.calculate_utxo
        block_utxo.each do |address, amount|
          @utxo_internal[-1][address] ||= get_unconfirmed(address)
          @utxo_internal[-1][address] = prec(@utxo_internal[-1][address] + amount)
        end
      end

      # show
    end

    def cut(index)
      @utxo_internal = @utxo_internal[0..index]
    end

    def show
      return unless @utxo_internal.size > CONFIRMATION + 1

      info "UTXO updated:"

      @utxo_internal[-(CONFIRMATION+1)].each do |address, amount|
        info " - #{address} #{light_green(amount)} (UNCONFIRMED #{light_green(get_unconfirmed(address))})"
      end
    end

    include Logger
    include Common::Num
    include Common::Color
  end
end
