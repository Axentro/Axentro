module ::Sushi::Core::Fees
  # todo
  # remove here (integrate into blockchain?)
  FEE_SEND       =   1_i64
  FEE_SCARS_BUY  = 100_i64
  FEE_SCARS_SELL =  10_i64

  def min_fee_of_action(action : String) : Int64
    case action
    when "send"
      return FEE_SEND
    when "scars_buy"
      return FEE_SCARS_BUY
    when "scars_sell"
      return FEE_SCARS_SELL
    end

    0_i64
  end
end
