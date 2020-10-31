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

require "./build_in/*"

module ::Axentro::Core::DApps::BuildIn
  BUILD_IN_DAPPS = %w(BlockchainInfo NodeInfo TransactionCreator UTXO Hra Token Indices Rejects Fees Messenger WalletInfo OfficialNode)

  {% for dapp in BUILD_IN_DAPPS %}
    @{{ dapp.id.underscore }} : {{ dapp.id }}?

    def {{ dapp.id.underscore }} : {{ dapp.id }}
      @{{ dapp.id.underscore }}.not_nil!
    end
  {% end %}
end
