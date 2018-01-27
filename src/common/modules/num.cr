module ::Sushi::Common::Num
  # def prec(float : Float64) : Float64
  #   ("%.8f" % float).to_f
  # end

  # will be removed
  def prec(int : Int64) : Int64
    int
  end
end
