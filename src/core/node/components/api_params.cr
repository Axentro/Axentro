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

module ::Axentro::Core::NodeComponents
  module APIParams
    # Used to specify a direction for the API
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

    # Used to specify a sorting field when retrieving blocks via the API
    enum BlockSortField
      Id
      Time

      def to_s
        case self
        when Time
          "timestamp"
        else
          "idx"
        end
      end
    end

    # Used to specify a sorting field when retrieving transactions via the API
    enum TransactionSortField
      Id
      Time

      def to_s
        case self
        when Time
          "timestamp"
        else
          "block_id"
        end
      end
    end

    def paginated(query_params, page = 1, per_page = 20, direction = Direction::Down, sort_field = 0)
      per_page_raw = query_params["per_page"]?.try &.to_i || per_page
      capped_per_page = per_page_raw > 100 ? 100 : per_page_raw
      [query_params["page"]?.try &.to_i || page,
       capped_per_page,
       query_params["direction"]?.try { |d| d == "up" ? 0 : 1 } || direction.value,
       query_params["sort_field"]?.try { |d| d == "time" ? 1 : 0 } || sort_field,
      ]
    end
  end
end
