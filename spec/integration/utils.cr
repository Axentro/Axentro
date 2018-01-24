require "./utils/*"

module ::Integration::Utils
  include Log
  include API
  include Node
  include Miner
  include Wallet
end
