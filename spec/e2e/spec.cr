require "./runner"

describe E2E do

  it "the integration test" do

    if ENV.has_key?("TRAVIS")
      runner = ::E2E::Runner.new(5, 5)
      runner.run!
    else
      STDERR.puts "skip integration test."
    end
  end
end
