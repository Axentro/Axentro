require "../src/core"

total_amount = 0_i64
current_index = 0_u64

loop do
  served_amount = ::Sushi::Core::Blockchain.served_amount(current_index)
  break if served_amount == 0

  total_amount += served_amount
  current_index += 1
end

puts "total amount: #{total_amount}"
