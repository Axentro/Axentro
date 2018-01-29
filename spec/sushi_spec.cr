require "./spec_helper"

puts "----- Unit tests -----"
require "./units/units"

puts "\n----- Integration test -----"
require "./integration/spec"

unless ARGV.includes?("--local")
  runner = ::Integration::Runner.new
  runner.run!

  sleep 10

  runner.fin
else
  puts "skip integration test."
end
