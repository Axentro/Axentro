require "./spec_helper"

include ::Sushi::Common::Color

puts light_cyan("> Unit tests")
require "./units/units"

puts "\n"
puts light_cyan("> E2E test")

ENV["E2E"] = "true" if ENV.has_key?("TRAVIS")

require "./e2e/spec"
