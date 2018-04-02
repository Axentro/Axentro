require "./../../spec_helper"
require "./../utils"

include Sushi::Core
include Sushi::Core::Keys

describe BlowFish do
  it "should encrypt and decrypt" do
    encrypted = BlowFish.encrypt("password", "some-data")
    decrypted = BlowFish.decrypt("password", encrypted[:data], encrypted[:salt])
    decrypted.should eq("some-data")
  end
end
