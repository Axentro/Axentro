include ::Garnet::Core::Num

describe ::Garnet::Core::Num do

  it "prec" do
    a = 0.0

    10000.times do |i|
      a = prec(a + 0.00000001)
      a.should eq(prec(0.00000001 * (i+1)))
    end
  end
end
