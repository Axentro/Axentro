module ::Sushi::Common::Num
  def prec(float : Float64) : Float64
    ("%.8f" % float).to_f
  end
end
