module ::Sushi::Common::Denomination
  SCALE_DECIMAL = 8

  def scale_i64(value : String) : Int64
    BigDecimal.new(value).scale_to(BigDecimal.new(1, SCALE_DECIMAL)).value.to_i64
  end

  def scale_decimal(value : Int64) : String
    BigDecimal.new(value, 8).to_s
  end
end
