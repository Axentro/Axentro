require "./../../spec_helper"

include Sushi::Core
include Sushi::Core::Consensus
# include Sushi::Core::Models
# include Hashes

describe Consensus do

  # def valid_sha256?(block_index : Int64, block_hash : String, nonce : UInt64, _difficulty : Int32?) : Bool
  #   difficulty = _difficulty.nil? ? difficulty_at(block_index) : _difficulty.not_nil!
  #   guess_nonce = "#{block_hash}#{nonce}"
  #   guess_hash = sha256(guess_nonce)
  #   guess_hash[0, difficulty] == "0" * difficulty
  # end

  describe "#valid_sha256?" do

    it "should return true when sha256 is valid" do
      # p block_101.to_hash
      c = 0.to_u64

      loop do
        v = valid_sha256?(1.to_i64, "block_hash", c, 1)
        p c
        break if v == true
        c = c + 1
      end
    end

  end


end

def block_101
  Block.from_json(%({"index":101,"transactions":[{"id":"4db42cdfcffc85c86734dc1bc00adcc21aae274a3137d6a16a31162a8d6ea7b2","action":"head","senders":[],"recipients":[{"address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyN\
WRmNWQ0","amount":4166.666666666667},{"address":"VDBhYTYxYzk5MTQ4M2QyZmU1YTA4NzUxZjYzYWUzYzA4ZTExYTgzMjdkNWViODU2","amount":3333.333333333333},{"address":"VDAyNTk0YjdlMTc4N2FkODRmYTU0YWZmODM1YzQzOTA2YTEzY2NjYmMyNjdkYjVm","amount":2500.0}\
],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}],"nonce":1441005721641889293,"prev_hash":"08101ac35b72e68db9670e1afc6b4566bc99a2c7df2772f6c03d18d39a3a5dce","merkle_tree_root":"9233320dac9af5421ea875977c94afe39c041cdb"}))
end
