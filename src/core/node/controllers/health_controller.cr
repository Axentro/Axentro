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

module ::Axentro::Core::Controllers
  class HealthController < Controller
    def exec_internal_get(context, params) : HTTP::Server::Context
      context.response.status_code == 200
      context
    end

    def exec_internal_post(json, context, params) : HTTP::Server::Context
      unpermitted_method(context)
    end
  end
end
