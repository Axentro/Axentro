require "./spec_helper"

include ::Sushi::Common::Color

ENV["UNIT"] = "true"

puts light_cyan("> Unit tests")
require "./units/units"

ENV["E2E"] = "true" if ENV.has_key?("TRAVIS")

puts "\n"
puts light_cyan("> E2E test")

require "./e2e/spec"
