require "./runner"

describe Integration do

  it "the integration test" do

    unless ARGV.includes?("--local")
      runner = ::Integration::Runner.new
      runner.run!.should be_true
    else
      puts "skip integration test."
    end
  end
end
