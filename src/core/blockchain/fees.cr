module ::Sushi::Core::Fees
  FEE_SEND = 0.1

  def min_fee_of_action(action : String) : Float64
    case action
    when "send"
      return FEE_SEND
    end

    0.0
  end
end
