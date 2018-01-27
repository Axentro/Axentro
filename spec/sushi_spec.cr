require "./spec_helper"

include ::Sushi::Common::Color

puts light_cyan("> Unit tests")
require "./units/*"

puts "\n"
puts light_cyan("> E2E test")
require "./e2e/spec"
