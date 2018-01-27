module ::Sushi::Core::Fees
  FEE_SEND = 1_i64

  def min_fee_of_action(action : String) : Int64
    case action
    when "send"
      return FEE_SEND
    end

    0_i64
  end
end
