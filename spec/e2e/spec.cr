require "./runner"

describe E2E do
  it "the integration test" do
    if ENV.has_key?("TRAVIS")
      num_nodes = ENV.has_key?("NUM_NODES") ? ENV["NUM_NODES"].to_i : 3
      num_miners = ENV.has_key?("NUM_MINERS") ? ENV["NUM_MINERS"].to_i : 3

      runner = ::E2E::Runner.new(num_nodes, num_miners)
      runner.run!
    else
      STDERR.puts "skip integration test."
    end
  end
end
