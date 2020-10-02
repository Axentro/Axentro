# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

ENV["AXE_TESTING"] = "true"

require "spec"
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

TOKEN_DEFAULT = Axentro::Core::DApps::BuildIn::UTXO::DEFAULT
