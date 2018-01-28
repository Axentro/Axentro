require "./utils/*"

module ::E2E::Utils
  include Log
  include API
  include Node
  include Miner
  include Wallet
end
