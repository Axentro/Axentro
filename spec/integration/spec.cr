require "./runner"

describe Integration do

  it "the integration test" do

    if ENV.has_key?("TRAVIS")
      runner = ::Integration::Runner.new
      runner.run!.should be_true
    else
      STDERR.puts "skip integration test."
    end
  end
end
