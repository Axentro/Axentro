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

require "./*"
require "./dapps/dapp"

module ::Axentro::Core::DApps
  getter dapps : Array(DApp) = [] of DApp

  def initialize_dapps
    {% for dapp in BUILD_IN_DAPPS %}
      debug "initializing {{dapp.id}}... (build in)"
      @{{ dapp.id.underscore }} = {{ dapp.id }}.new(self)
      @dapps.push(@{{ dapp.id.underscore }}.not_nil!)
    {% end %}
  rescue e : Exception
    error "error happens during initializing dApps"
    error "reason:"
    error e.message.not_nil!

    exit -1
  end

  def setup_dapps
    {% for dapp in BUILD_IN_DAPPS %}
      begin
        @{{ dapp.id.underscore }}.not_nil!.setup
      rescue e : Exception
        warning "error happens during setup dApps"
        warning "reason:"
        warning e.message.not_nil!
        warning "the dApp will be removed and be ignored"

        @dapps.delete(@{{ dapp.id.underscore }}.not_nil!)
      end
    {% end %}
  end

  include Logger
  include BuildIn
end
