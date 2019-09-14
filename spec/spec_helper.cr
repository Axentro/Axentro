# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "spec"
require "./ext/spec/*"
require "yaml"
require "../src/common"
require "../src/core"
require "./utils/*"

module ::Units::Utils
  include TransactionHelper
  include WalletHelper
  include NodeHelper
  include ChainGenerator
  include FunctionalHelper
end

TOKEN_DEFAULT = Sushi::Core::DApps::BuildIn::UTXO::DEFAULT
