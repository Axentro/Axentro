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

module ::Sushi::Core::NodeComponents
  module APIParams
    enum Direction
      Up
      Down

      def to_s
        case self
        when Up
          "asc"
        else
          "desc"
        end
      end
    end

    def paginated(query_params, page = 0, per_page = 20, direction = Direction::Down)
      per_page = per_page > 100 ? 100 : per_page
      [query_params["page"]?.try &.to_i || page,
       query_params["per_page"]?.try &.to_i || per_page,
       query_params["direction"]?.try{|d| d == "up" ? 0 : 1 } || direction.value
      ]
    end
  end
end
