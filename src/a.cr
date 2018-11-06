a = (0..100).map {|n| n}
b = a.last(2)
p b.last - b.first
